import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

/// GeneratedDatabase mínima escrita a mano (sin codegen): core_drift opera
/// con SQL crudo, así que no declara tablas Drift (ADR-0006).
class TestDatabase extends GeneratedDatabase {
  TestDatabase() : super(NativeDatabase.memory());

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// En Windows el paquete sqlite3 busca sqlite3.dll; si no está en el PATH,
/// caemos a winsqlite3.dll (incluida en Windows 10+).
void configureSqliteNativeLibrary() {
  if (!Platform.isWindows) return;
  open.overrideFor(OperatingSystem.windows, () {
    for (final lib in ['sqlite3.dll', 'winsqlite3.dll']) {
      try {
        return DynamicLibrary.open(lib);
      } catch (_) {}
    }
    throw StateError('No se encontró sqlite3.dll ni winsqlite3.dll');
  });
}

class TestEvent implements DomainEvent {
  @override
  final String eventType;
  final String data;

  TestEvent(this.eventType, this.data);

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {'data': data};
}

DefaultEventTypeRegistry testRegistry() => DefaultEventTypeRegistry()
  ..register('test.logged', 1,
      (json) => TestEvent('test.logged', json['data'] as String));

/// Projector REAL contra la misma database: mantiene un contador por
/// agregado en una tabla. Sirve para probar que sus escrituras comparten
/// la transacción del append (atomicidad) y la prueba ácida.
class SqlCountProjector implements Projector {
  final GeneratedDatabase db;

  SqlCountProjector(this.db);

  @override
  String get name => 'test.counts';

  @override
  Set<String> get handledEventTypes => {'test.logged'};

  Future<void> createTable() => db.customStatement(
      'CREATE TABLE IF NOT EXISTS test_counts '
      '(aggregate_id TEXT NOT NULL PRIMARY KEY, n INTEGER NOT NULL)');

  @override
  FutureOr<void> project(EventEnvelope envelope) {
    return db.customStatement(
      'INSERT INTO test_counts (aggregate_id, n) VALUES (?, 1) '
      'ON CONFLICT (aggregate_id) DO UPDATE SET n = n + 1',
      [envelope.streamId.aggregateId],
    );
  }

  @override
  Future<void> reset() => db.customStatement('DELETE FROM test_counts');

  Future<int> countFor(String aggregateId) async {
    final row = await db.customSelect(
      'SELECT n FROM test_counts WHERE aggregate_id = ?',
      variables: [Variable<String>(aggregateId)],
    ).getSingleOrNull();
    return row?.read<int>('n') ?? 0;
  }
}

/// Projector saboteador: siempre lanza. Para probar el rollback del append.
class ThrowingProjector implements Projector {
  @override
  String get name => 'test.bomb';

  @override
  Set<String> get handledEventTypes => {'test.logged'};

  @override
  FutureOr<void> project(EventEnvelope envelope) {
    throw StateError('proyección saboteada');
  }

  @override
  Future<void> reset() async {}
}
