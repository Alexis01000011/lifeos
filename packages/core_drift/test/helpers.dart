import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

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

DefaultEventTypeRegistry<DomainEvent> testRegistry() =>
    DefaultEventTypeRegistry<DomainEvent>()
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
