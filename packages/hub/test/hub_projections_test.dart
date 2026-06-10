import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:hub/hub.dart';
import 'package:test/test.dart';

/// El hub consume integration events SIN conocer a gym: estos tests
/// publican el contrato directamente al log (como lo haría cualquier
/// módulo productor) y verifican la proyección del hub.
void main() {
  setUpAll(configureSqliteNativeLibrary);

  late TestDatabase db;
  late DriftIntegrationEventLog log;
  late IntegrationProjectionEngine engine;
  late HubReadModels readModels;
  var causa = 0;

  setUp(() async {
    causa = 0;
    db = TestDatabase();
    await createEventStoreSchema(db); // projection_checkpoints
    await createIntegrationEventSchema(db);
    await createHubReadModelSchema(db);

    final registry = DefaultEventTypeRegistry<IntegrationEvent>();
    registerHubIntegrationEvents(registry);
    engine = IntegrationProjectionEngine(
      [WeeklyWorkoutCountProjector(db)],
      DriftProjectionCheckpointStore(db),
    );
    log = DriftIntegrationEventLog(db, registry, engine);
    readModels = HubReadModels(db);
  });

  tearDown(() => db.close());

  Future<void> publicar(DateTime completedAt) => log.publish(
        GymWorkoutCompleted(workoutId: 'w${++causa}', completedAt: completedAt),
        causationEventId: 'de-$causa',
        sourceModule: 'gym',
        occurredAt: completedAt,
      );

  test('cuenta entrenos por semana ISO usando el completed_at del contrato',
      () async {
    await publicar(DateTime.utc(2026, 6, 10, 18)); // miércoles
    await publicar(DateTime.utc(2026, 6, 13, 10)); // sábado, misma semana
    await publicar(DateTime.utc(2026, 6, 15, 18)); // lunes siguiente

    expect(await readModels.workoutsInWeek('2026-06-08'), 2);
    expect(await readModels.workoutsInWeek('2026-06-15'), 1);
    expect(await readModels.workoutsInWeek('2026-06-01'), 0);

    final semanas = await readModels.weeklyWorkouts();
    expect([for (final s in semanas) s.weekStart], ['2026-06-15', '2026-06-08']);
  });

  test('roundtrip del contrato v1 tal como llega del log', () async {
    final completedAt = DateTime.utc(2026, 6, 10, 18, 30);
    await publicar(completedAt);

    final envelope = (await log.readAll().toList()).single;
    final evento = envelope.event as GymWorkoutCompleted;
    expect(evento.workoutId, 'w1');
    expect(evento.completedAt, completedAt);
  });

  test('PRUEBA ÁCIDA del hub: reset + replay del log = estado idéntico',
      () async {
    await publicar(DateTime.utc(2026, 6, 10, 18));
    await publicar(DateTime.utc(2026, 6, 13, 10));
    await publicar(DateTime.utc(2026, 6, 15, 18));

    Future<List<Map<String, Object?>>> snapshot() async {
      final rows = await db
          .customSelect('SELECT * FROM $hubWeeklyWorkoutsTable ORDER BY 1')
          .get();
      return rows.map((r) => r.data).toList();
    }

    final antes = await snapshot();
    expect(antes, isNotEmpty);

    await engine.rebuild(log.readAll());

    expect(await snapshot(), antes);
  });
}
