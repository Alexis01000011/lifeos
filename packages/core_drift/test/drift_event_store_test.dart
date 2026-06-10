import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  setUpAll(configureSqliteNativeLibrary);

  late TestDatabase db;
  late DriftProjectionCheckpointStore checkpoints;
  late SqlCountProjector projector;
  late DriftEventStore store;

  const stream = StreamId('test.aggregate', 'a1');

  setUp(() async {
    db = TestDatabase();
    await createEventStoreSchema(db);
    checkpoints = DriftProjectionCheckpointStore(db);
    projector = SqlCountProjector(db);
    await projector.createTable();
    store = DriftEventStore(
      db,
      testRegistry(),
      ProjectionEngine([projector], checkpoints),
    );
  });

  tearDown(() => db.close());

  Future<int> totalEvents() async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS c FROM events').getSingle();
    return row.read<int>('c');
  }

  group('append', () {
    test('asigna metadata completa y versiones consecutivas', () async {
      final envelopes = await store.append(
        stream,
        [TestEvent('test.logged', 'uno'), TestEvent('test.logged', 'dos')],
        expectedVersion: EventStore.noStream,
      );

      expect(envelopes.map((e) => e.streamVersion), [1, 2]);
      expect(envelopes.map((e) => e.globalSequence), [1, 2]);
      expect(envelopes.map((e) => e.eventId).toSet(), hasLength(2));
      expect(envelopes.every((e) => e.occurredAt.isUtc), isTrue);
    });

    test('con expectedVersion desactualizado lanza ConcurrencyException '
        'y no persiste nada', () async {
      await store.append(stream, [TestEvent('test.logged', 'uno')],
          expectedVersion: EventStore.noStream);

      // Segundo escritor que rehidrató antes del primer append.
      await expectLater(
        store.append(stream, [TestEvent('test.logged', 'tarde')],
            expectedVersion: EventStore.noStream),
        throwsA(isA<ConcurrencyException>()),
      );
      expect(await totalEvents(), 1);
    });

    test('vacío no toca la base', () async {
      expect(await store.append(stream, [], expectedVersion: 0), isEmpty);
      expect(await totalEvents(), 0);
    });

    test('proyecta de forma síncrona en el mismo append', () async {
      await store.append(stream, [TestEvent('test.logged', 'uno')],
          expectedVersion: EventStore.noStream);

      expect(await projector.countFor('a1'), 1);
      expect(await checkpoints.getCheckpoint('test.counts'), 1);
    });

    test('un projector que lanza revierte el append ENTERO '
        '(eventos + proyecciones en una transacción)', () async {
      final sabotaged = DriftEventStore(
        db,
        testRegistry(),
        ProjectionEngine([projector, ThrowingProjector()], checkpoints),
      );

      await expectLater(
        sabotaged.append(stream, [TestEvent('test.logged', 'uno')],
            expectedVersion: EventStore.noStream),
        throwsA(isA<StateError>()),
      );

      expect(await totalEvents(), 0, reason: 'el evento no debe persistir');
      expect(await projector.countFor('a1'), 0,
          reason: 'la proyección previa al sabotaje debe revertirse');
      expect(await checkpoints.getCheckpoint('test.counts'), 0);
    });
  });

  group('lectura', () {
    test('readStream devuelve orden por streamVersion y respeta fromVersion',
        () async {
      await store.append(
        stream,
        [
          TestEvent('test.logged', 'uno'),
          TestEvent('test.logged', 'dos'),
          TestEvent('test.logged', 'tres'),
        ],
        expectedVersion: EventStore.noStream,
      );

      final all = await store.readStream(stream);
      expect(all.map((e) => e.streamVersion), [1, 2, 3]);
      expect(all.map((e) => (e.event as TestEvent).data),
          ['uno', 'dos', 'tres']);

      final tail = await store.readStream(stream, fromVersion: 2);
      expect(tail.map((e) => e.streamVersion), [2, 3]);
    });

    test('readStream de un stream inexistente devuelve lista vacía', () async {
      expect(await store.readStream(const StreamId('test.aggregate', 'nadie')),
          isEmpty);
    });

    test('readAll devuelve orden global entre streams y fromGlobalSequence '
        'es exclusivo', () async {
      const otro = StreamId('test.aggregate', 'a2');
      await store.append(stream, [TestEvent('test.logged', 'a1-1')],
          expectedVersion: EventStore.noStream);
      await store.append(otro, [TestEvent('test.logged', 'a2-1')],
          expectedVersion: EventStore.noStream);
      await store.append(stream, [TestEvent('test.logged', 'a1-2')],
          expectedVersion: 1);

      final all = await store.readAll().toList();
      expect(all.map((e) => e.globalSequence), [1, 2, 3]);

      final tail = await store.readAll(fromGlobalSequence: 1).toList();
      expect(tail.map((e) => e.globalSequence), [2, 3]);
    });

    test('roundtrip: lo leído reconstruye el evento vía registry', () async {
      final escrito = await store.append(
          stream, [TestEvent('test.logged', 'ñandú 💪')],
          expectedVersion: EventStore.noStream);

      final leido = (await store.readStream(stream)).single;
      expect((leido.event as TestEvent).data, 'ñandú 💪');
      expect(leido.eventId, escrito.single.eventId);
      expect(leido.occurredAt, escrito.single.occurredAt);
    });
  });

  test('prueba ácida: reset + rebuild desde readAll = estado idéntico',
      () async {
    const otro = StreamId('test.aggregate', 'a2');
    await store.append(
      stream,
      [TestEvent('test.logged', 'uno'), TestEvent('test.logged', 'dos')],
      expectedVersion: EventStore.noStream,
    );
    await store.append(otro, [TestEvent('test.logged', 'uno')],
        expectedVersion: EventStore.noStream);

    final antes = [await projector.countFor('a1'), await projector.countFor('a2')];
    expect(antes, [2, 1]);

    final engine = ProjectionEngine([projector], checkpoints);
    await engine.rebuild(store.readAll());

    expect([await projector.countFor('a1'), await projector.countFor('a2')],
        antes);
    expect(await checkpoints.getCheckpoint('test.counts'), 3);
  });

  test('checkpoint store: 0 por defecto y upsert sobreescribe', () async {
    expect(await checkpoints.getCheckpoint('fantasma'), 0);
    await checkpoints.saveCheckpoint('p', 7);
    await checkpoints.saveCheckpoint('p', 9);
    expect(await checkpoints.getCheckpoint('p'), 9);
  });
}
