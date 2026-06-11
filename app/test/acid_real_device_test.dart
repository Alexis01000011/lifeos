import 'dart:io';

import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/gym.dart';
import 'package:hub/hub.dart';
import 'package:lifeos_app/src/database.dart';

/// Prueba ácida contra bases REALES extraídas del dispositivo (ADR-0001):
/// reset de proyecciones + replay del event store y del log de integración
/// debe reproducir exactamente el estado que el teléfono construyó en vivo.
///
/// Soporta las dos generaciones de read model (ADR-0010): si la captura es
/// de la app vieja (acumuladores gym_weekly_volume / hub_weekly_workouts),
/// se comparan los AGREGADOS equivalentes derivados de las tablas
/// granulares nuevas; si es de la app nueva, se comparan las tablas tal
/// cual. El historial y el log de integración se comparan siempre.
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

      Future<bool> existe(String table) async => (await db.customSelect(
              "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
              variables: [Variable<String>(table)]).get())
          .isNotEmpty;

      Future<List<String>> filas(String sql) async =>
          [for (final r in await db.customSelect(sql).get()) r.data.toString()];

      // Estado EN VIVO, capturado en forma agnóstica a la generación.
      final historiaVivo =
          await filas('SELECT * FROM $workoutHistoryTable ORDER BY workout_id');
      final volumenVivo = await existe('gym_weekly_volume')
          ? await filas('SELECT week_start, total_volume_kg '
              'FROM gym_weekly_volume ORDER BY week_start')
          : await filas('SELECT week_start, SUM(weight_kg * reps) '
              'AS total_volume_kg FROM $gymSetsTable '
              'GROUP BY week_start ORDER BY week_start');
      final hubVivo = await existe('hub_weekly_workouts')
          ? await filas('SELECT week_start, workout_count '
              'FROM hub_weekly_workouts ORDER BY week_start')
          : await filas('SELECT week_start, COUNT(*) AS workout_count '
              'FROM $hubWorkoutsTable GROUP BY week_start ORDER BY week_start');
      final integracionVivo = await filas(
          'SELECT * FROM $integrationEventsTable ORDER BY sequence');

      final eventCount = (await db
              .customSelect('SELECT COUNT(*) AS n FROM events')
              .getSingle())
          .data['n'] as int;
      expect(eventCount, greaterThan(0),
          reason: 'una base real sin eventos no prueba nada');

      // Migrar al schema actual (crea las granulares, dropea acumuladores)
      // y reconstruir con la composición vigente de projectors.
      await createGymReadModelSchema(db);
      await createHubReadModelSchema(db);

      final integrationRegistry = DefaultEventTypeRegistry<IntegrationEvent>();
      registerHubIntegrationEvents(integrationRegistry);
      final hubEngine = IntegrationProjectionEngine(
        [HubWorkoutsProjector(db)],
        DriftProjectionCheckpointStore(db),
      );
      final log = DriftIntegrationEventLog(db, integrationRegistry, hubEngine);

      final registry = DefaultEventTypeRegistry<DomainEvent>();
      registerGymEvents(registry);
      final engine = ProjectionEngine(
        [
          WorkoutHistoryProjector(db),
          WorkoutSetsProjector(db),
          ExerciseCatalogProjector(db),
          PublishWorkoutCompletedPolicy(log),
          PublishWorkoutDiscardedPolicy(log),
        ],
        DriftProjectionCheckpointStore(db),
      );
      final store = DriftEventStore(db, registry, engine);

      await engine.rebuild(store.readAll());
      await hubEngine.rebuild(log.readAll());

      expect(
          await filas(
              'SELECT * FROM $workoutHistoryTable ORDER BY workout_id'),
          historiaVivo,
          reason: 'el historial replayado debe calcar al vivo');
      expect(
          await filas('SELECT week_start, SUM(weight_kg * reps) '
              'AS total_volume_kg FROM $gymSetsTable '
              'GROUP BY week_start ORDER BY week_start'),
          volumenVivo,
          reason: 'el volumen semanal derivado de gym_sets debe calcar al '
              'que el dispositivo acumuló en vivo');
      expect(
          await filas('SELECT week_start, COUNT(*) AS workout_count '
              'FROM $hubWorkoutsTable GROUP BY week_start '
              'ORDER BY week_start'),
          hubVivo,
          reason: 'el conteo del hub derivado de hub_workouts debe calcar '
              'al acumulado en vivo');
      expect(
          await filas(
              'SELECT * FROM $integrationEventsTable ORDER BY sequence'),
          integracionVivo,
          reason: 'lo publicado no se despublica: el log de integración no '
              'cambia con un rebuild');
    });
  }
}
