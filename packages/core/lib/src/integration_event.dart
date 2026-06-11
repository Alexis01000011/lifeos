import 'dart:async';

import 'projection.dart';

/// Contrato público entre módulos (VISION, Reglas 2-4).
///
/// Un [IntegrationEvent] NO es un [DomainEvent]: el domain event es detalle
/// interno del módulo y cambia con libertad; el integration event es API
/// pública versionada y se trata con más conservadurismo. Son tipos
/// distintos a propósito: el sistema de tipos impide publicar un domain
/// event al exterior o appendear un integration event al event store.
///
/// El contrato real es el JSON documentado en docs/integration-events.md,
/// no la clase Dart: el módulo productor y el hub tienen cada uno su propia
/// clase (schema-first, como entre servicios). Regla 1: el hub no importa
/// al módulo.
abstract class IntegrationEvent {
  /// Nombre estable, p. ej. 'gym.workout_completed'. Puede coincidir con el
  /// de un domain event homónimo: viven en logs distintos.
  String get eventType;

  /// Versión del contrato público. Cambiarla rompe suscriptores: weak
  /// schema + upcasters, con más conservadurismo que en domain events.
  int get schemaVersion => 1;

  Map<String, dynamic> toJson();
}

/// Metadata de transporte del log de integración. Los consumidores deciden
/// con el payload del evento (el contrato); el envelope es orden e
/// idempotencia.
class IntegrationEventEnvelope {
  /// Posición en el log de integración (orden total). Checkpoint de los
  /// projectors del hub. Espacio de secuencias INDEPENDIENTE del
  /// globalSequence del event store.
  final int sequence;

  /// Identificador único del integration event (UUID).
  final String eventId;

  /// eventId del domain event que lo originó. Clave de idempotencia del
  /// outbox: publicar dos veces por la misma causa = una sola publicación.
  final String causationEventId;

  /// Módulo productor, p. ej. 'gym'.
  final String sourceModule;

  /// Timestamp del domain event causante (ADR-0003: tiempo de persistencia;
  /// el tiempo de negocio, si importa, va en el payload del contrato).
  final DateTime occurredAt;

  final IntegrationEvent event;

  const IntegrationEventEnvelope({
    required this.sequence,
    required this.eventId,
    required this.causationEventId,
    required this.sourceModule,
    required this.occurredAt,
    required this.event,
  });
}

/// Puerto del log de integración (patrón outbox, ADR-0009).
abstract class IntegrationEventLog {
  /// Publica si y solo si [causationEventId] no publicó ya: idempotente
  /// frente a replays. Devuelve el envelope persistido, o null si era
  /// duplicado. La implementación despacha a los suscriptores del hub
  /// dentro de la misma transacción.
  Future<IntegrationEventEnvelope?> publish(
    IntegrationEvent event, {
    required String causationEventId,
    required String sourceModule,
    required DateTime occurredAt,
  });

  /// Todo el log en orden de [IntegrationEventEnvelope.sequence], para
  /// rebuild de proyecciones del hub.
  Stream<IntegrationEventEnvelope> readAll({int fromSequence = 0});
}

/// Proyección del hub sobre el log de integración (Regla 3: el hub solo
/// conoce integration events). Mismo contrato que [Projector] pero sobre
/// el otro log; la prueba ácida del hub es reset + readAll del log de
/// integración.
abstract class IntegrationProjector {
  /// Nombre estable, p. ej. 'hub.weekly_workouts'. Comparte el
  /// ProjectionCheckpointStore con los projectors de domain events: los
  /// nombres no deben colisionar (los espacios de secuencia difieren).
  String get name;

  Set<String> get handledEventTypes;

  FutureOr<void> project(IntegrationEventEnvelope envelope);

  Future<void> reset();
}

/// Espejo de ProjectionEngine para el log de integración. Mantenerlos
/// separados es deliberado: envelopes distintos, espacios de secuencia
/// distintos; unificarlos con genéricos se evaluará si la duplicación
/// duele al crecer (ADR-0009).
class IntegrationProjectionEngine {
  final List<IntegrationProjector> _projectors;
  final ProjectionCheckpointStore _checkpoints;

  IntegrationProjectionEngine(this._projectors, this._checkpoints);

  Future<void> project(IntegrationEventEnvelope envelope) async {
    for (final projector in _projectors) {
      if (!projector.handledEventTypes.contains(envelope.event.eventType)) {
        continue;
      }
      final checkpoint = await _checkpoints.getCheckpoint(projector.name);
      if (envelope.sequence <= checkpoint) continue;
      await projector.project(envelope);
      await _checkpoints.saveCheckpoint(projector.name, envelope.sequence);
    }
  }

  /// Catch-up sin reset (espejo del de ProjectionEngine, ADR-0010): la
  /// guarda de checkpoint salta lo ya procesado; un projector nuevo se
  /// backfillea desde el log completo.
  Future<void> catchUp(Stream<IntegrationEventEnvelope> events) async {
    await for (final envelope in events) {
      await project(envelope);
    }
  }

  Future<void> rebuild(Stream<IntegrationEventEnvelope> events) async {
    for (final projector in _projectors) {
      await projector.reset();
      await _checkpoints.saveCheckpoint(projector.name, 0);
    }
    await catchUp(events);
  }
}
