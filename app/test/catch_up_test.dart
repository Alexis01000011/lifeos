import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/gym.dart';
import 'package:hub/hub.dart';
import 'package:lifeos_app/src/providers.dart';

/// El escenario de upgrade del A71 (ADR-0010): la versión vieja de la app
/// persistió eventos con OTRO juego de projectors; la nueva trae
/// gym_sets y hub_workouts, que nacen vacíos y con checkpoint 0. El
/// catch-up del arranque debe backfillearlos desde los logs sin tocar lo
/// que ya estaba al día.
void main() {
  setUpAll(configureSqliteNativeLibrary);

  testWidgets('catchUpProjections backfillea projectors nuevos desde ambos '
      'logs', (tester) async {
    final db = TestDatabase();
    addTearDown(db.close);
    await createEventStoreSchema(db);
    await createIntegrationEventSchema(db);
    await createGymReadModelSchema(db);
    await createHubReadModelSchema(db);

    // "Versión vieja": historial + policy de publicación, sin projector de
    // series y con un log de integración sin consumidores.
    final domainRegistry = DefaultEventTypeRegistry<DomainEvent>();
    registerGymEvents(domainRegistry);
    final integrationRegistry = DefaultEventTypeRegistry<IntegrationEvent>();
    final oldLog = DriftIntegrationEventLog(
      db,
      integrationRegistry,
      IntegrationProjectionEngine(const [], DriftProjectionCheckpointStore(db)),
    );
    final oldEngine = ProjectionEngine(
      [WorkoutHistoryProjector(db), PublishWorkoutCompletedPolicy(oldLog)],
      DriftProjectionCheckpointStore(db),
    );
    final oldStore = DriftEventStore(db, domainRegistry, oldEngine,
        clock: () => DateTime.utc(2026, 6, 10, 18));

    final workouts = workoutRepository(oldStore);
    await StartWorkoutHandler(workouts).handle(StartWorkout('w1'));
    await LogSetHandler(workouts).handle(LogSet(
        workoutId: 'w1', exercise: 'sentadilla', weightKg: 80, reps: 10));
    await CompleteWorkoutHandler(workouts).handle(CompleteWorkout('w1'));

    // "Versión nueva": la composición real de providers + catch-up.
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) => db)],
    );
    addTearDown(container.dispose);
    await catchUpProjections(container);

    final volumen = await GymReadModels(db).weeklyVolume();
    expect(volumen.single.weekStart, '2026-06-08');
    expect(volumen.single.totalVolumeKg, 800,
        reason: 'gym_sets se backfilleó desde el event store');

    expect(await HubReadModels(db).workoutsInWeek('2026-06-08'), 1,
        reason: 'hub_workouts se backfilleó desde el log de integración');

    final historia = await GymReadModels(db).workoutHistory();
    expect(historia.single.setCount, 1,
        reason: 'el projector veterano no reprocesó nada');
  });
}
