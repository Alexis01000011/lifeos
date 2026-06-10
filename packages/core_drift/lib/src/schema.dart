import 'package:drift/drift.dart';

/// DDL de las dos tablas de infraestructura del event store.
///
/// No son tablas Drift declaradas (ADR-0006): la migración de la app no
/// las conoce, así que la app debe llamar a [createEventStoreSchema] en su
/// arranque (es idempotente: CREATE TABLE IF NOT EXISTS).
///
/// `global_sequence` es INTEGER PRIMARY KEY AUTOINCREMENT: alias del rowid,
/// estrictamente creciente y sin reutilización — la base del orden total
/// que exige el contrato de EventStore.
/// El UNIQUE(aggregate_type, aggregate_id, stream_version) es la red de
/// seguridad física de la concurrencia optimista: aunque un bug saltara
/// el chequeo de expectedVersion, dos escrituras a la misma versión no
/// pueden coexistir.
Future<void> createEventStoreSchema(GeneratedDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS events (
      global_sequence INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id        TEXT    NOT NULL UNIQUE,
      aggregate_type  TEXT    NOT NULL,
      aggregate_id    TEXT    NOT NULL,
      stream_version  INTEGER NOT NULL,
      event_type      TEXT    NOT NULL,
      schema_version  INTEGER NOT NULL,
      payload         TEXT    NOT NULL,
      occurred_at     INTEGER NOT NULL,
      UNIQUE (aggregate_type, aggregate_id, stream_version)
    )
  ''');
  await db.customStatement('''
    CREATE INDEX IF NOT EXISTS idx_events_stream
      ON events (aggregate_type, aggregate_id, stream_version)
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS projection_checkpoints (
      projector_name  TEXT    NOT NULL PRIMARY KEY,
      global_sequence INTEGER NOT NULL
    )
  ''');
}
