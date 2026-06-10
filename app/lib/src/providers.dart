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

/// Log de integración (ADR-0009): el outbox por donde los módulos publican
/// sus contratos y el canal del que el hub proyecta. Sus despachos corren
/// dentro de la transacción del append.
final integrationEventLogProvider = Provider<IntegrationEventLog>((ref) {
  final db = ref.watch(databaseProvider);
  final registry = DefaultEventTypeRegistry<IntegrationEvent>();
  registerHubIntegrationEvents(registry);
  final hubEngine = IntegrationProjectionEngine(
    [WeeklyWorkoutCountProjector(db)],
    DriftProjectionCheckpointStore(db),
  );
  return DriftIntegrationEventLog(db, registry, hubEngine);
});

/// Event store con proyecciones síncronas: registry y engine viven dentro
/// porque comparten ciclo de vida con el store (un grafo por database).
/// Las policies de publicación (Regla 2) se registran junto a los
/// projectors del módulo: misma transacción, misma guarda de checkpoint.
final eventStoreProvider = Provider<EventStore>((ref) {
  final db = ref.watch(databaseProvider);
  final registry = DefaultEventTypeRegistry<DomainEvent>();
  registerGymEvents(registry);
  final engine = ProjectionEngine(
    [
      WorkoutHistoryProjector(db),
      WeeklyVolumeProjector(db),
      PublishWorkoutCompletedPolicy(ref.watch(integrationEventLogProvider)),
    ],
    DriftProjectionCheckpointStore(db),
  );
  return DriftEventStore(db, registry, engine);
});

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

final gymReadModelsProvider = Provider<GymReadModels>(
  (ref) => GymReadModels(ref.watch(databaseProvider)),
);

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
  return watchQuery(db, {weeklyVolumeTable}, readModels.weeklyVolume);
});

final hubReadModelsProvider = Provider<HubReadModels>(
  (ref) => HubReadModels(ref.watch(databaseProvider)),
);

/// Read model del hub para la pantalla de inicio.
final weeklyWorkoutCountsProvider =
    StreamProvider<List<WeeklyWorkoutCount>>((ref) {
  final db = ref.watch(databaseProvider);
  final readModels = ref.watch(hubReadModelsProvider);
  return watchQuery(db, {hubWeeklyWorkoutsTable}, readModels.weeklyWorkouts);
});

/// Derivado del historial: el workout en curso (completed_at NULL), si
/// existe. La pantalla de loggear pivota sobre esto.
final activeWorkoutProvider = Provider<AsyncValue<WorkoutSummary?>>((ref) {
  return ref.watch(workoutHistoryProvider).whenData(
        (workouts) => workouts.where((w) => w.isInProgress).firstOrNull,
      );
});
