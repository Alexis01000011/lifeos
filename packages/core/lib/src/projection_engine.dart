import 'domain_event.dart';
import 'projection.dart';

/// Despachador del lado de lectura (ADR-0004). El event store persiste;
/// este engine reparte los envelopes a los projectors interesados y
/// mantiene sus checkpoints. Es la única pieza que conoce a los projectors.
///
/// El mismo despacho sirve para las dos caras:
/// - [projectAll]: lo invoca el store dentro de la transacción de append
///   (las escrituras de los projectors se unen a esa transacción).
/// - [rebuild]: reset de todos los projectors + replay completo desde
///   readAll(). Es la mecánica de la prueba ácida.
///
/// Puro Dart: no conoce Drift ni transacciones. La atomicidad la garantiza
/// quien lo invoca (el store, vía transacciones zone-based).
class ProjectionEngine {
  final List<Projector> _projectors;
  final ProjectionCheckpointStore _checkpoints;

  ProjectionEngine(this._projectors, this._checkpoints);

  /// Despacha un envelope a cada projector que declare su eventType.
  ///
  /// Guarda de idempotencia: si el checkpoint del projector ya está en o
  /// después de este globalSequence, se salta (en replay parcial o
  /// reintentos pasará). El checkpoint solo avanza con eventos manejados:
  /// puede quedar "atrás" respecto del global, nunca adelantado.
  Future<void> project(EventEnvelope envelope) async {
    for (final projector in _projectors) {
      if (!projector.handledEventTypes.contains(envelope.event.eventType)) {
        continue;
      }
      final checkpoint = await _checkpoints.getCheckpoint(projector.name);
      if (envelope.globalSequence <= checkpoint) continue;
      await projector.project(envelope);
      await _checkpoints.saveCheckpoint(
          projector.name, envelope.globalSequence);
    }
  }

  /// Despacha en orden los envelopes recién persistidos por un append.
  Future<void> projectAll(Iterable<EventEnvelope> envelopes) async {
    for (final envelope in envelopes) {
      await project(envelope);
    }
  }

  /// Catch-up sin reset: despacha el historial confiando en la guarda de
  /// checkpoint (lo ya procesado se salta). Es como un projector nuevo o
  /// renombrado —checkpoint 0— se backfillea con los eventos que se
  /// persistieron antes de que existiera; la app lo corre al arrancar
  /// (ADR-0010).
  Future<void> catchUp(Stream<EventEnvelope> events) async {
    await for (final envelope in events) {
      await project(envelope);
    }
  }

  /// Prueba ácida: borra todos los modelos de lectura y los reconstruye
  /// desde el historial completo ([events] viene de EventStore.readAll()).
  /// Tras esto, el estado debe ser idéntico al previo — por eso ejercita
  /// exactamente el mismo despacho que el camino de producción.
  Future<void> rebuild(Stream<EventEnvelope> events) async {
    for (final projector in _projectors) {
      await projector.reset();
      await _checkpoints.saveCheckpoint(projector.name, 0);
    }
    await catchUp(events);
  }
}
