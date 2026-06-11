import 'package:core/core.dart';

/// Vista CONSUMIDORA de los contratos que el hub escucha. El contrato
/// canónico es el JSON de docs/integration-events.md; gym tiene su propia
/// clase productora. Duplicar la clase por lado es deliberado (Regla 1:
/// el hub no importa módulos) — como dos servicios que comparten un
/// schema, no código.

/// `gym.workout_completed` v1.
class GymWorkoutCompleted implements IntegrationEvent {
  static const type = 'gym.workout_completed';

  final String workoutId;
  final DateTime completedAt;

  GymWorkoutCompleted({required this.workoutId, required this.completedAt});

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'workout_id': workoutId,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };

  static GymWorkoutCompleted fromJson(Map<String, dynamic> json) =>
      GymWorkoutCompleted(
        workoutId: json['workout_id'] as String,
        completedAt: DateTime.parse(json['completed_at'] as String),
      );
}

/// `gym.workout_discarded` v1: compensatorio — anula al workout_completed
/// del mismo workout (ADR-0010).
class GymWorkoutDiscarded implements IntegrationEvent {
  static const type = 'gym.workout_discarded';

  final String workoutId;
  final DateTime discardedAt;

  GymWorkoutDiscarded({required this.workoutId, required this.discardedAt});

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'workout_id': workoutId,
        'discarded_at': discardedAt.toUtc().toIso8601String(),
      };

  static GymWorkoutDiscarded fromJson(Map<String, dynamic> json) =>
      GymWorkoutDiscarded(
        workoutId: json['workout_id'] as String,
        discardedAt: DateTime.parse(json['discarded_at'] as String),
      );
}

/// Registra los deserializadores de los contratos consumidos. La app shell
/// lo llama al componer el registry de integration events.
void registerHubIntegrationEvents(EventTypeRegistry<IntegrationEvent> registry) {
  registry.register(GymWorkoutCompleted.type, 1, GymWorkoutCompleted.fromJson);
  registry.register(GymWorkoutDiscarded.type, 1, GymWorkoutDiscarded.fromJson);
}
