import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Implementación Drift/SQLite del puerto [EventStore].
///
/// Opera con SQL crudo sobre la [GeneratedDatabase] compuesta por la app
/// (ADR-0006): así el append y las escrituras de los projectors comparten
/// la misma transacción zone-based de Drift, que es lo que vuelve atómico
/// el par "persistir eventos + actualizar proyecciones" (ADR-0001).
///
/// Genera aquí `eventId` (UUID v4) y `occurredAt` (UTC) — ADR-0003: la
/// metadata de persistencia es responsabilidad de la infraestructura.
class DriftEventStore implements EventStore {
  final GeneratedDatabase _db;
  final EventTypeRegistry _registry;
  final ProjectionEngine _engine;
  final Uuid _uuid = const Uuid();

  DriftEventStore(this._db, this._registry, this._engine);

  @override
  Future<List<EventEnvelope>> append(
    StreamId streamId,
    List<DomainEvent> events, {
    required int expectedVersion,
  }) {
    if (events.isEmpty) return Future.value(const []);

    // Todo dentro de una transacción: el chequeo de versión, los inserts y
    // las proyecciones síncronas. Si cualquier paso lanza (incluido un
    // projector), no queda NADA persistido.
    return _db.transaction(() async {
      final current = await _currentStreamVersion(streamId);
      if (current != expectedVersion) {
        throw ConcurrencyException(streamId, expectedVersion, current);
      }

      final occurredAt = DateTime.now().toUtc();
      final envelopes = <EventEnvelope>[];
      var version = expectedVersion;
      for (final event in events) {
        version++;
        final eventId = _uuid.v4();
        final globalSequence = await _db.customInsert(
          'INSERT INTO events (event_id, aggregate_type, aggregate_id, '
          'stream_version, event_type, schema_version, payload, occurred_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<String>(eventId),
            Variable<String>(streamId.aggregateType),
            Variable<String>(streamId.aggregateId),
            Variable<int>(version),
            Variable<String>(event.eventType),
            Variable<int>(event.schemaVersion),
            Variable<String>(jsonEncode(event.toJson())),
            // Microsegundos: el envelope devuelto por append y el leído
            // de disco deben ser idénticos (roundtrip sin pérdida).
            Variable<int>(occurredAt.microsecondsSinceEpoch),
          ],
        );
        envelopes.add(EventEnvelope(
          eventId: eventId,
          streamId: streamId,
          streamVersion: version,
          globalSequence: globalSequence,
          occurredAt: occurredAt,
          event: event,
        ));
      }

      await _engine.projectAll(envelopes);
      return envelopes;
    });
  }

  @override
  Future<List<EventEnvelope>> readStream(
    StreamId streamId, {
    int fromVersion = 1,
  }) async {
    final rows = await _db.customSelect(
      'SELECT * FROM events '
      'WHERE aggregate_type = ? AND aggregate_id = ? AND stream_version >= ? '
      'ORDER BY stream_version',
      variables: [
        Variable<String>(streamId.aggregateType),
        Variable<String>(streamId.aggregateId),
        Variable<int>(fromVersion),
      ],
    ).get();
    return rows.map(_toEnvelope).toList();
  }

  @override
  Stream<EventEnvelope> readAll({int fromGlobalSequence = 0}) async* {
    // Volumen local-first (decenas de eventos/día): una lectura completa
    // alcanza. Si algún día duele, este método pagina por dentro sin
    // cambiar el contrato.
    final rows = await _db.customSelect(
      'SELECT * FROM events WHERE global_sequence > ? '
      'ORDER BY global_sequence',
      variables: [Variable<int>(fromGlobalSequence)],
    ).get();
    for (final row in rows) {
      yield _toEnvelope(row);
    }
  }

  Future<int> _currentStreamVersion(StreamId streamId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(MAX(stream_version), 0) AS v FROM events '
      'WHERE aggregate_type = ? AND aggregate_id = ?',
      variables: [
        Variable<String>(streamId.aggregateType),
        Variable<String>(streamId.aggregateId),
      ],
    ).getSingle();
    return row.read<int>('v');
  }

  EventEnvelope _toEnvelope(QueryRow row) {
    final event = _registry.deserialize(
      row.read<String>('event_type'),
      row.read<int>('schema_version'),
      jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
    );
    return EventEnvelope(
      eventId: row.read<String>('event_id'),
      streamId: StreamId(
        row.read<String>('aggregate_type'),
        row.read<String>('aggregate_id'),
      ),
      streamVersion: row.read<int>('stream_version'),
      globalSequence: row.read<int>('global_sequence'),
      occurredAt: DateTime.fromMicrosecondsSinceEpoch(
        row.read<int>('occurred_at'),
        isUtc: true,
      ),
      event: event,
    );
  }
}
