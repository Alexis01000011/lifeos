import 'domain_event.dart';

/// Se lanza cuando expectedVersion no coincide con la versión real del stream.
/// Localmente es casi imposible que pase (un solo usuario), pero el contrato
/// la incluye porque el día que haya sync multi-dispositivo será vital.
class ConcurrencyException implements Exception {
  final StreamId streamId;
  final int expectedVersion;
  final int actualVersion;
  ConcurrencyException(this.streamId, this.expectedVersion, this.actualVersion);

  @override
  String toString() =>
      'Conflicto en $streamId: se esperaba v$expectedVersion, hay v$actualVersion';
}

/// Puerto hexagonal del event store. La implementación (Drift) vive en
/// infraestructura; el dominio solo conoce esta interfaz.
///
/// Invariantes que TODA implementación debe garantizar:
/// 1. Append-only: nunca se actualiza ni borra un evento persistido.
/// 2. Atomicidad: un append de N eventos se persiste completo o no se persiste.
/// 3. Orden total: globalSequence es estrictamente creciente, sin huecos visibles.
/// 4. Concurrencia optimista: append falla si expectedVersion != versión actual.
abstract class EventStore {
  /// Versión esperada cuando el stream aún no existe.
  static const int noStream = 0;

  /// Persiste [events] al final del stream.
  ///
  /// [expectedVersion]: la streamVersion que el caller leyó al rehidratar.
  /// Si otro escritor metió eventos en medio, lanza [ConcurrencyException].
  ///
  /// NOTA (decisión 2026-06-09): la implementación Drift actualizará las
  /// proyecciones síncronas DENTRO de esta misma transacción. Eso es detalle
  /// de infraestructura: este contrato no lo promete ni lo prohíbe.
  Future<List<EventEnvelope>> append(
    StreamId streamId,
    List<DomainEvent> events, {
    required int expectedVersion,
  });

  /// Lee los eventos de un agregado para rehidratarlo.
  /// [fromVersion] permite leer desde un snapshot (futuro; hoy siempre 1).
  Future<List<EventEnvelope>> readStream(
    StreamId streamId, {
    int fromVersion = 1,
  });

  /// Lee TODOS los eventos en orden global desde [fromGlobalSequence]
  /// (exclusivo). Es la fuente para reconstruir proyecciones (replay).
  Stream<EventEnvelope> readAll({int fromGlobalSequence = 0});
}
