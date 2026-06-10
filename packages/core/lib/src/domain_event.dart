/// Contrato base de los hechos del dominio.
///
/// Un [DomainEvent] es un hecho inmutable que ya ocurrió. Nunca se edita ni
/// se borra; los errores se corrigen emitiendo eventos compensatorios.
abstract class DomainEvent {
  /// Nombre estable del tipo de evento, p. ej. 'gym.workout_logged'.
  /// NO usar runtimeType: el nombre persiste aunque renombres la clase Dart.
  String get eventType;

  /// Versión del esquema de ESTE tipo de evento (no del agregado).
  /// Empieza en 1; sube cuando cambia la forma del payload. Ver upcasters.
  int get schemaVersion => 1;

  Map<String, dynamic> toJson();
}

/// Identidad de un stream: un agregado concreto de un tipo concreto.
/// Ej.: ('gym.workout', 'uuid-del-workout').
class StreamId {
  final String aggregateType;
  final String aggregateId;
  const StreamId(this.aggregateType, this.aggregateId);

  @override
  bool operator ==(Object other) =>
      other is StreamId &&
      other.aggregateType == aggregateType &&
      other.aggregateId == aggregateId;

  @override
  int get hashCode => Object.hash(aggregateType, aggregateId);

  @override
  String toString() => '$aggregateType/$aggregateId';
}

/// Sobre que envuelve al evento con la metadata de persistencia.
/// El evento es el "qué pasó"; el envelope es el "dónde/cuándo/en qué orden".
class EventEnvelope {
  /// Identificador único del evento (UUID). Clave de idempotencia.
  final String eventId;

  final StreamId streamId;

  /// Posición dentro del stream del agregado (1, 2, 3...).
  /// Base de la concurrencia optimista.
  final int streamVersion;

  /// Posición global en el event store completo (autoincremental).
  /// Es el checkpoint de las proyecciones: orden total de todos los eventos.
  final int globalSequence;

  /// Timestamp de persistencia, generado por el store en el append
  /// (ADR-0003). Es metadata de auditoría: si un evento necesita tiempo
  /// de negocio (p. ej. registro en diferido), va como campo del payload.
  final DateTime occurredAt;

  final DomainEvent event;

  const EventEnvelope({
    required this.eventId,
    required this.streamId,
    required this.streamVersion,
    required this.globalSequence,
    required this.occurredAt,
    required this.event,
  });
}
