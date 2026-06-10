import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

/// El lado público del módulo: la policy traduce el domain event
/// gym.workout_completed al contrato de integración homónimo (ADR-0009).
void main() {
  setUpAll(configureSqliteNativeLibrary);

  late TestDatabase db;
  late ProjectionEngine engine;
  late DriftEventStore store;
  late DriftIntegrationEventLog log;
  late StartWorkoutHandler start;
  late LogSetHandler logSet;
  late CompleteWorkoutHandler complete;

  final completedAt = DateTime.utc(2026, 6, 10, 18);

  setUp(() async {
    db = TestDatabase();
    await createEventStoreSchema(db);
    await createGymReadModelSchema(db);
    await createIntegrationEventSchema(db);

    final registry = DefaultEventTypeRegistry<DomainEvent>();
    registerGymEvents(registry);
    final integrationRegistry = DefaultEventTypeRegistry<IntegrationEvent>()
      ..register(WorkoutCompletedIntegrationEvent.type, 1,
          WorkoutCompletedIntegrationEvent.fromJson);
    log = DriftIntegrationEventLog(
      db,
      integrationRegistry,
      IntegrationProjectionEngine(const [], DriftProjectionCheckpointStore(db)),
    );
    engine = ProjectionEngine(
      [WorkoutHistoryProjector(db), PublishWorkoutCompletedPolicy(log)],
      DriftProjectionCheckpointStore(db),
    );
    store = DriftEventStore(db, registry, engine, clock: () => completedAt);

    final workouts = workoutRepository(store);
    start = StartWorkoutHandler(workouts);
    logSet = LogSetHandler(workouts);
    complete = CompleteWorkoutHandler(workouts);
  });

  tearDown(() => db.close());

  Future<void> entrenoCompleto(String id) async {
    await start.handle(StartWorkout(id));
    await logSet.handle(
        LogSet(workoutId: id, exercise: 'sentadilla', weightKg: 80, reps: 10));
    await complete.handle(CompleteWorkout(id));
  }

  test('completar un workout publica el contrato v1 con su payload', () async {
    await entrenoCompleto('w1');

    final publicados = await log.readAll().toList();
    expect(publicados, hasLength(1));
    final envelope = publicados.single;
    expect(envelope.sourceModule, 'gym');
    expect(envelope.occurredAt, completedAt);

    final evento = envelope.event as WorkoutCompletedIntegrationEvent;
    expect(evento.eventType, 'gym.workout_completed');
    expect(evento.workoutId, 'w1');
    expect(evento.completedAt, completedAt);
    expect(evento.toJson(), {
      'workout_id': 'w1',
      'completed_at': '2026-06-10T18:00:00.000Z',
    });
  });

  test('un workout sin completar no publica nada', () async {
    await start.handle(StartWorkout('w1'));
    await logSet.handle(
        LogSet(workoutId: 'w1', exercise: 'press banca', weightKg: 60, reps: 8));

    expect(await log.readAll().toList(), isEmpty);
  });

  test('lo publicado no se despublica: el rebuild no duplica ni borra',
      () async {
    await entrenoCompleto('w1');
    await entrenoCompleto('w2');
    final antes = await log.readAll().toList();
    expect(antes, hasLength(2));

    // Rebuild del engine principal: la policy se re-ejecuta sobre toda la
    // historia, pero la idempotencia por causation_event_id la frena.
    await engine.rebuild(store.readAll());

    final despues = await log.readAll().toList();
    expect(despues, hasLength(2));
    expect([for (final e in despues) e.eventId],
        [for (final e in antes) e.eventId],
        reason: 'mismas publicaciones, ni una más');
  });
}
