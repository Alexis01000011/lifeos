import 'dart:io';

import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/gym.dart';
import 'package:hub/hub.dart';
import 'package:lifeos_app/src/database.dart';

/// Prueba ácida contra bases REALES extraídas del dispositivo (ADR-0001):
/// reset de proyecciones + replay del event store y del log de integración
/// debe reproducir exactamente el estado que el teléfono construyó en vivo.
///
/// Uso: jalar la base con
///   adb exec-out run-as dev.alexis.lifeos_app cat app_flutter/lifeos.sqlite \
///     > tmp/dispositivo-fecha.sqlite
/// y correr `flutter test test/acid_real_device_test.dart`. Si tmp/ no tiene
/// bases, el test se salta (no corre en CI ni en máquinas sin extracción).
void main() {
  final dumps = Directory('../tmp')
          .existsSync()
      ? Directory('../tmp')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sqlite'))
          .toList()
      : <File>[];

  if (dumps.isEmpty) {
    test('prueba acida con base real', () {},
        skip: 'no hay bases en tmp/*.sqlite');
    return;
  }

  for (final dump in dumps) {
    test('prueba acida con base real: ${dump.uri.pathSegments.last}',
        () async {
      // Copia de trabajo: el rebuild muta proyecciones y la extracción
      // original debe quedar intacta como evidencia.
      final copy = File('${dump.path}.acid-copy');
      dump.copySync(copy.path);
      addTearDown(() {
        if (copy.existsSync()) copy.deleteSync();
      });

      final db = AppDatabase(NativeDatabase(copy));
      addTearDown(db.close);

      // Misma composición que providers.dart, sin Riverpod: acá el sujeto
      // bajo prueba son los engines reconstruyendo, no la UI.
      final integrationRegistry = DefaultEventTypeRegistry<IntegrationEvent>();
      registerHubIntegrationEvents(integrationRegistry);
      final hubEngine = IntegrationProjectionEngine(
        [WeeklyWorkoutCountProjector(db)],
        DriftProjectionCheckpointStore(db),
      );
      final log = DriftIntegrationEventLog(db, integrationRegistry, hubEngine);

      final registry = DefaultEventTypeRegistry<DomainEvent>();
      registerGymEvents(registry);
      final engine = ProjectionEngine(
        [
          WorkoutHistoryProjector(db),
          WeeklyVolumeProjector(db),
          PublishWorkoutCompletedPolicy(log),
        ],
        DriftProjectionCheckpointStore(db),
      );
      final store = DriftEventStore(db, registry, engine);

      Future<Map<String, List<String>>> snapshot() async {
        final tables = {
          workoutHistoryTable: 'workout_id',
          weeklyVolumeTable: 'week_start',
          hubWeeklyWorkoutsTable: 'week_start',
          integrationEventsTable: 'sequence',
          'projection_checkpoints': 'projector_name',
        };
        final result = <String, List<String>>{};
        for (final entry in tables.entries) {
          final rows = await db
              .customSelect(
                  'SELECT * FROM ${entry.key} ORDER BY ${entry.value}')
              .get();
          result[entry.key] = [for (final r in rows) r.data.toString()];
        }
        return result;
      }

      final eventCount = (await db
              .customSelect('SELECT COUNT(*) AS n FROM events')
              .getSingle())
          .data['n'] as int;
      expect(eventCount, greaterThan(0),
          reason: 'una base real sin eventos no prueba nada');

      final vivo = await snapshot();

      await engine.rebuild(store.readAll());
      await hubEngine.rebuild(log.readAll());

      final replay = await snapshot();

      expect(replay, equals(vivo),
          reason: 'reset + replay debe reproducir el estado que el '
              'dispositivo construyo en vivo, tabla por tabla');
    });
  }
}
