import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';
import 'package:hub/hub.dart';

/// Composition root (ADR-0002: Riverpod es estado Y DI). Aquí —y solo
/// aquí— se cablean los módulos con la infraestructura: la app shell es
/// la única capa que puede depender de todos.

/// main() lo overridea con la database real ya abierta; los tests, con
/// una en memoria. Nadie más construye databases.
final databaseProvider = Provider<GeneratedDatabase>(
  (ref) => throw UnimplementedError('main() inyecta la database abierta'),
);

/// Engine del hub, expuesto (no embebido en el log) porque el catch-up del
/// arranque lo necesita: un projector nuevo o renombrado nace con
/// checkpoint 0 y se backfillea desde el log de integración (ADR-0010).
final integrationEngineProvider = Provider<IntegrationProjectionEngine>((ref) {
  final db = ref.watch(databaseProvider);
  return IntegrationProjectionEngine(
    [HubWorkoutsProjector(db)],
    DriftProjectionCheckpointStore(db),
  );
});

/// Log de integración (ADR-0009): el outbox por donde los módulos publican
/// sus contratos y el canal del que el hub proyecta. Sus despachos corren
/// dentro de la transacción del append.
final integrationEventLogProvider = Provider<IntegrationEventLog>((ref) {
  final db = ref.watch(databaseProvider);
  final registry = DefaultEventTypeRegistry<IntegrationEvent>();
  registerHubIntegrationEvents(registry);
  return DriftIntegrationEventLog(
      db, registry, ref.watch(integrationEngineProvider));
});

/// Engine de domain events, expuesto por la misma razón que el del hub.
/// Las policies de publicación (Regla 2) se registran junto a los
/// projectors del módulo: misma transacción, misma guarda de checkpoint.
final projectionEngineProvider = Provider<ProjectionEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final log = ref.watch(integrationEventLogProvider);
  return ProjectionEngine(
    [
      WorkoutHistoryProjector(db),
      WorkoutSetsProjector(db),
      ExerciseCatalogProjector(db),
      PublishWorkoutCompletedPolicy(log),
      PublishWorkoutDiscardedPolicy(log),
    ],
    DriftProjectionCheckpointStore(db),
  );
});

/// Event store con proyecciones síncronas: registry y engine comparten
/// ciclo de vida con el store (un grafo por database).
final eventStoreProvider = Provider<EventStore>((ref) {
  final db = ref.watch(databaseProvider);
  final registry = DefaultEventTypeRegistry<DomainEvent>();
  registerGymEvents(registry);
  return DriftEventStore(db, registry, ref.watch(projectionEngineProvider));
});

/// Catch-up del arranque (ADR-0010): despacha la historia completa de ambos
/// logs confiando en la guarda de checkpoint — los projectors al día no
/// reprocesan nada; los nuevos se backfillean. Atómico: o entero o nada.
/// main() lo corre antes de runApp; los tests de widget no lo necesitan
/// (sus databases nacen vacías) pero pueden llamarlo para simular upgrades.
Future<void> catchUpProjections(ProviderContainer container) async {
  final db = container.read(databaseProvider);
  final log = container.read(integrationEventLogProvider);
  final store = container.read(eventStoreProvider);
  await db.transaction(() async {
    // Integración primero: publish() no re-despacha duplicados (vuelve
    // temprano por causation id), así que el backfill del hub solo puede
    // venir del replay del log, no de las policies del catch-up de dominio.
    await container.read(integrationEngineProvider).catchUp(log.readAll());
    await container.read(projectionEngineProvider).catchUp(store.readAll());
  });
}

final _workoutsProvider = Provider<AggregateRepository<Workout>>(
  (ref) => workoutRepository(ref.watch(eventStoreProvider)),
);

final startWorkoutProvider = Provider<StartWorkoutHandler>(
  (ref) => StartWorkoutHandler(ref.watch(_workoutsProvider)),
);
final logSetProvider = Provider<LogSetHandler>(
  (ref) => LogSetHandler(ref.watch(_workoutsProvider)),
);
final completeWorkoutProvider = Provider<CompleteWorkoutHandler>(
  (ref) => CompleteWorkoutHandler(ref.watch(_workoutsProvider)),
);
final discardWorkoutProvider = Provider<DiscardWorkoutHandler>(
  (ref) => DiscardWorkoutHandler(ref.watch(_workoutsProvider)),
);
final addMissedSetProvider = Provider<AddMissedSetHandler>(
  (ref) => AddMissedSetHandler(ref.watch(_workoutsProvider)),
);

final _exerciseCatalogProvider =
    Provider<AggregateRepository<ExerciseCatalog>>(
  (ref) => exerciseCatalogRepository(ref.watch(eventStoreProvider)),
);

final addExerciseProvider = Provider<AddExerciseHandler>(
  (ref) => AddExerciseHandler(ref.watch(_exerciseCatalogProvider)),
);
final renameExerciseProvider = Provider<RenameExerciseHandler>(
  (ref) => RenameExerciseHandler(ref.watch(_exerciseCatalogProvider)),
);

final gymReadModelsProvider = Provider<GymReadModels>(
  (ref) => GymReadModels(ref.watch(databaseProvider)),
);

/// Catálogo de ejercicios (ADR-0011), reactivo para el picker y la
/// pantalla Ejercicios.
final exercisesProvider = StreamProvider<List<ExerciseSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  final readModels = ref.watch(gymReadModelsProvider);
  return watchQuery(db, {gymExercisesTable}, readModels.exercises);
});

/// Los read models como streams: watchQuery re-consulta cuando los
/// projectors notifican la tabla (ADR-0008). La UI solo ve AsyncValue.
final workoutHistoryProvider = StreamProvider<List<WorkoutSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  final readModels = ref.watch(gymReadModelsProvider);
  return watchQuery(db, {workoutHistoryTable}, readModels.workoutHistory);
});

final weeklyVolumeProvider = StreamProvider<List<WeeklyVolume>>((ref) {
  final db = ref.watch(databaseProvider);
  final readModels = ref.watch(gymReadModelsProvider);
  return watchQuery(db, {gymSetsTable}, readModels.weeklyVolume);
});

final hubReadModelsProvider = Provider<HubReadModels>(
  (ref) => HubReadModels(ref.watch(databaseProvider)),
);

/// Read model del hub para la pantalla de inicio.
final weeklyWorkoutCountsProvider =
    StreamProvider<List<WeeklyWorkoutCount>>((ref) {
  final db = ref.watch(databaseProvider);
  final readModels = ref.watch(hubReadModelsProvider);
  return watchQuery(db, {hubWorkoutsTable}, readModels.weeklyWorkouts);
});

/// Derivado del historial: el workout en curso (completed_at NULL), si
/// existe. La pantalla de loggear pivota sobre esto.
final activeWorkoutProvider = Provider<AsyncValue<WorkoutSummary?>>((ref) {
  return ref.watch(workoutHistoryProvider).whenData(
        (workouts) => workouts.where((w) => w.isInProgress).firstOrNull,
      );
});
