import '../domain_event.dart';
import '../event_store.dart';
import '../projection_engine.dart';

/// EventStore en memoria para tests de módulos: respeta el contrato
/// (orden, concurrencia optimista, fromVersion/fromGlobalSequence) sin
/// tocar disco.
///
/// Diferencia deliberada con la implementación real: si el [engine]
/// opcional lanza a mitad de las proyecciones, aquí NO hay rollback de
/// los eventos ya agregados. La atomicidad es propiedad de la
/// implementación Drift (transacciones); probarla es asunto de los tests
/// de core_drift, no de los tests de dominio.
class InMemoryEventStore implements EventStore {
  final ProjectionEngine? engine;
  final List<EventEnvelope> _log = [];
  int _globalSequence = 0;

  InMemoryEventStore({this.engine});

  /// El historial completo, para asserts directos en tests.
  List<EventEnvelope> get log => List.unmodifiable(_log);

  @override
  Future<List<EventEnvelope>> append(
    StreamId streamId,
    List<DomainEvent> events, {
    required int expectedVersion,
  }) async {
    if (events.isEmpty) return const [];

    final current =
        _log.where((envelope) => envelope.streamId == streamId).length;
    if (current != expectedVersion) {
      throw ConcurrencyException(streamId, expectedVersion, current);
    }

    final appended = <EventEnvelope>[];
    var version = expectedVersion;
    for (final event in events) {
      version++;
      _globalSequence++;
      appended.add(EventEnvelope(
        eventId: 'evt-$_globalSequence',
        streamId: streamId,
        streamVersion: version,
        globalSequence: _globalSequence,
        occurredAt: DateTime.now().toUtc(),
        event: event,
      ));
    }
    _log.addAll(appended);
    await engine?.projectAll(appended);
    return appended;
  }

  @override
  Future<List<EventEnvelope>> readStream(
    StreamId streamId, {
    int fromVersion = 1,
  }) async {
    return _log
        .where((envelope) =>
            envelope.streamId == streamId &&
            envelope.streamVersion >= fromVersion)
        .toList();
  }

  @override
  Stream<EventEnvelope> readAll({int fromGlobalSequence = 0}) {
    return Stream.fromIterable(_log
        .where((envelope) => envelope.globalSequence > fromGlobalSequence));
  }
}
