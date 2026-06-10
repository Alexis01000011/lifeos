import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'schema.dart';

/// Implementación Drift del puerto [IntegrationEventLog] (ADR-0009).
///
/// publish() corre dentro de la transacción del append (lo invoca una
/// policy despachada por el ProjectionEngine): persistir el integration
/// event, despachar a los projectors del hub y el append del domain event
/// son UNA operación atómica.
///
/// Idempotencia del outbox: si `causationEventId` ya publicó, no pasa
/// nada (ni fila nueva ni despacho). Así las policies son re-ejecutables
/// en replay sin duplicar historia pública — y lo publicado no se
/// despublica jamás.
class DriftIntegrationEventLog implements IntegrationEventLog {
  final GeneratedDatabase _db;
  final EventTypeRegistry<IntegrationEvent> _registry;
  final IntegrationProjectionEngine _engine;
  final Uuid _uuid = const Uuid();

  DriftIntegrationEventLog(this._db, this._registry, this._engine);

  @override
  Future<IntegrationEventEnvelope?> publish(
    IntegrationEvent event, {
    required String causationEventId,
    required String sourceModule,
    required DateTime occurredAt,
  }) async {
    final existing = await _db.customSelect(
      'SELECT sequence FROM integration_events WHERE causation_event_id = ?',
      variables: [Variable<String>(causationEventId)],
    ).getSingleOrNull();
    if (existing != null) return null;

    final eventId = _uuid.v4();
    final occurredAtUtc = occurredAt.toUtc();
    final payload = jsonEncode(event.toJson());
    final sequence = await _db.customInsert(
      'INSERT INTO integration_events (event_id, causation_event_id, '
      'source_module, event_type, schema_version, payload, occurred_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(eventId),
        Variable<String>(causationEventId),
        Variable<String>(sourceModule),
        Variable<String>(event.eventType),
        Variable<int>(event.schemaVersion),
        Variable<String>(payload),
        Variable<int>(occurredAtUtc.microsecondsSinceEpoch),
      ],
    );

    // El despacho pasa por el "cable" (serializar → deserializar): los
    // suscriptores reciben SU representación del contrato según el
    // registry, nunca el objeto del productor. La frontera schema-first
    // es real también en vivo — en replay y en vivo llega lo mismo.
    if (_registry.knows(event.eventType)) {
      final envelope = IntegrationEventEnvelope(
        sequence: sequence,
        eventId: eventId,
        causationEventId: causationEventId,
        sourceModule: sourceModule,
        occurredAt: occurredAtUtc,
        event: _registry.deserialize(
          event.eventType,
          event.schemaVersion,
          jsonDecode(payload) as Map<String, dynamic>,
        ),
      );
      // Proyecciones del hub, síncronas y en la misma transacción.
      await _engine.project(envelope);
    }
    // Sin consumidor registrado el contrato igual se persistió: un
    // suscriptor futuro lo verá en el replay.

    _db.notifyUpdates({const TableUpdate(integrationEventsTable)});
    return IntegrationEventEnvelope(
      sequence: sequence,
      eventId: eventId,
      causationEventId: causationEventId,
      sourceModule: sourceModule,
      occurredAt: occurredAtUtc,
      event: event,
    );
  }

  @override
  Stream<IntegrationEventEnvelope> readAll({int fromSequence = 0}) async* {
    final rows = await _db.customSelect(
      'SELECT * FROM integration_events WHERE sequence > ? ORDER BY sequence',
      variables: [Variable<int>(fromSequence)],
    ).get();
    for (final row in rows) {
      // Tipo sin consumidor actual: legítimo, se salta (queda en el log).
      // Una VERSIÓN inalcanzable de un tipo conocido sí explota dentro de
      // deserialize: eso es un bug de upcasters, no un tipo huérfano.
      if (!_registry.knows(row.read<String>('event_type'))) continue;
      yield IntegrationEventEnvelope(
        sequence: row.read<int>('sequence'),
        eventId: row.read<String>('event_id'),
        causationEventId: row.read<String>('causation_event_id'),
        sourceModule: row.read<String>('source_module'),
        occurredAt: DateTime.fromMicrosecondsSinceEpoch(
          row.read<int>('occurred_at'),
          isUtc: true,
        ),
        event: _registry.deserialize(
          row.read<String>('event_type'),
          row.read<int>('schema_version'),
          jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
        ),
      );
    }
  }
}
