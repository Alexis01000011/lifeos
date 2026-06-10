import 'dart:async';

import 'package:core/core.dart';

import 'events.dart';

/// Lado público del módulo (VISION Regla 2): lo que gym anuncia al resto
/// del sistema. El contrato canónico es el JSON documentado en
/// docs/integration-events.md; esta clase es solo la vista del productor
/// (el hub tiene la suya propia — Regla 1: nadie importa a gym).

/// `gym.workout_completed` v1 — homónimo del domain event a propósito,
/// pero contrato distinto en log distinto: este es API pública y cambia
/// con mucho más conservadurismo.
class WorkoutCompletedIntegrationEvent implements IntegrationEvent {
  static const type = 'gym.workout_completed';

  final String workoutId;

  /// Tiempo de negocio del contrato (hoy = occurredAt del domain event;
  /// cuando exista registro en diferido, será la hora real del entreno).
  final DateTime completedAt;

  WorkoutCompletedIntegrationEvent({
    required this.workoutId,
    required this.completedAt,
  });

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'workout_id': workoutId,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };

  static WorkoutCompletedIntegrationEvent fromJson(Map<String, dynamic> json) =>
      WorkoutCompletedIntegrationEvent(
        workoutId: json['workout_id'] as String,
        completedAt: DateTime.parse(json['completed_at'] as String),
      );
}

/// Policy de publicación: escucha el domain event y traduce al contrato.
///
/// Corre como un Projector más del ProjectionEngine (misma transacción que
/// el append), pero con semántica de outbox:
/// - idempotente vía el UNIQUE de causation_event_id en el log — un replay
///   re-ejecuta la policy sin duplicar publicaciones;
/// - reset() es no-op: LO PUBLICADO NO SE DESPUBLICA. Un rebuild de
///   proyecciones reconstruye modelos de lectura, no reescribe la API
///   pública ya emitida (Regla 4).
class PublishWorkoutCompletedPolicy implements Projector {
  final IntegrationEventLog _log;

  PublishWorkoutCompletedPolicy(this._log);

  @override
  String get name => 'gym.policy.workout_completed';

  @override
  Set<String> get handledEventTypes => {WorkoutCompleted.type};

  @override
  FutureOr<void> project(EventEnvelope envelope) {
    return _log.publish(
      WorkoutCompletedIntegrationEvent(
        workoutId: envelope.streamId.aggregateId,
        completedAt: envelope.occurredAt,
      ),
      causationEventId: envelope.eventId,
      sourceModule: 'gym',
      occurredAt: envelope.occurredAt,
    );
  }

  @override
  Future<void> reset() async {
    // No-op deliberado: el log de integración no es una proyección.
  }
}
