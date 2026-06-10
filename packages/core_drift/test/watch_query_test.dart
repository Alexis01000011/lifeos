import 'dart:async';

import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:drift/drift.dart';
import 'package:test/test.dart';

/// El helper de reactividad de ADR-0008: notifyUpdates → re-query.
void main() {
  setUpAll(configureSqliteNativeLibrary);

  late TestDatabase db;

  setUp(() async {
    db = TestDatabase();
    await db.customStatement(
        'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
  });

  tearDown(() => db.close());

  Future<List<String>> names() async {
    final rows =
        await db.customSelect('SELECT name FROM items ORDER BY id').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  Future<void> insert(String name) async {
    await db.customInsert('INSERT INTO items (name) VALUES (?)',
        variables: [Variable<String>(name)]);
    db.notifyUpdates({const TableUpdate('items')});
  }

  test('emite el estado inicial y re-emite tras cada notifyUpdates',
      () async {
    await insert('a');

    final emissions = <List<String>>[];
    final sub = watchQuery(db, {'items'}, names).listen(emissions.add);
    await pumpEventQueue();
    expect(emissions, [
      ['a']
    ]);

    await insert('b');
    await pumpEventQueue();
    expect(emissions, [
      ['a'],
      ['a', 'b'],
    ]);

    await sub.cancel();
  });

  test('ignora notificaciones de tablas ajenas', () async {
    final emissions = <List<String>>[];
    final sub = watchQuery(db, {'items'}, names).listen(emissions.add);
    await pumpEventQueue();

    db.notifyUpdates({const TableUpdate('otra_tabla')});
    await pumpEventQueue();

    expect(emissions, hasLength(1));
    await sub.cancel();
  });

  test('una escritura concurrente con la query inicial no se pierde',
      () async {
    // La query inicial es lenta; mientras corre, llega una escritura.
    var slow = true;
    Future<List<String>> slowNames() async {
      if (slow) {
        slow = false;
        await insert('durante-query-inicial');
      }
      return names();
    }

    final emissions = <List<String>>[];
    final sub = watchQuery(db, {'items'}, slowNames).listen(emissions.add);
    await pumpEventQueue();

    expect(emissions.last, ['durante-query-inicial']);
    expect(emissions, hasLength(2),
        reason: 'la notificación durante la query inicial dispara re-query');
    await sub.cancel();
  });
}
