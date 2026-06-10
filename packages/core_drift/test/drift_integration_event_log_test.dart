import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:test/test.dart';

class PingPublished implements IntegrationEvent {
  static const type = 'test.ping_published';

  final String label;
  PingPublished(this.label);

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {'label': label};

  static PingPublished fromJson(Map<String, dynamic> json) =>
      PingPublished(json['label'] as String);
}

/// Clase del lado PRODUCTOR para el mismo contrato test.ping_published:
/// mismo JSON, otra clase Dart (como gym y hub, que no se importan).
class ProducerSidePing implements IntegrationEvent {
  final String label;
  ProducerSidePing(this.label);

  @override
  String get eventType => PingPublished.type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {'label': label};
}

/// Contrato sin consumidor: nadie lo registra en el registry.
class OrphanEvent implements IntegrationEvent {
  @override
  String get eventType => 'test.orphan';

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {};
}

class CountingProjector implements IntegrationProjector {
  @override
  String get name => 'test.hub_counts';

  @override
  Set<String> get handledEventTypes => {PingPublished.type};

  final List<String> seen = [];

  @override
  Future<void> project(IntegrationEventEnvelope envelope) async {
    seen.add((envelope.event as PingPublished).label);
  }

  @override
  Future<void> reset() async => seen.clear();
}

void main() {
  setUpAll(configureSqliteNativeLibrary);

  late TestDatabase db;
  late CountingProjector projector;
  late DriftIntegrationEventLog log;

  setUp(() async {
    db = TestDatabase();
    await createEventStoreSchema(db); // projection_checkpoints vive ahí
    await createIntegrationEventSchema(db);
    final registry = DefaultEventTypeRegistry<IntegrationEvent>()
      ..register(PingPublished.type, 1, PingPublished.fromJson);
    projector = CountingProjector();
    log = DriftIntegrationEventLog(
      db,
      registry,
      IntegrationProjectionEngine(
          [projector], DriftProjectionCheckpointStore(db)),
    );
  });

  tearDown(() => db.close());

  test('publish persiste, asigna secuencia creciente y despacha al hub',
      () async {
    final a = await log.publish(PingPublished('a'),
        causationEventId: 'de-1',
        sourceModule: 'test',
        occurredAt: DateTime.utc(2026, 6, 10, 18));
    final b = await log.publish(PingPublished('b'),
        causationEventId: 'de-2',
        sourceModule: 'test',
        occurredAt: DateTime.utc(2026, 6, 10, 19));

    expect(a!.sequence, 1);
    expect(b!.sequence, 2);
    expect(projector.seen, ['a', 'b']);
  });

  test('la misma causa publica a lo sumo una vez (idempotencia del outbox)',
      () async {
    await log.publish(PingPublished('a'),
        causationEventId: 'de-1',
        sourceModule: 'test',
        occurredAt: DateTime.utc(2026, 6, 10));
    final repetido = await log.publish(PingPublished('a-bis'),
        causationEventId: 'de-1',
        sourceModule: 'test',
        occurredAt: DateTime.utc(2026, 6, 10));

    expect(repetido, isNull);
    expect(projector.seen, ['a'], reason: 'tampoco se despacha de nuevo');
    final filas =
        await db.customSelect('SELECT * FROM integration_events').get();
    expect(filas, hasLength(1));
  });

  test(
      'el despacho en vivo pasa por el cable: el suscriptor recibe la '
      'representación del registry, no el objeto del productor', () async {
    // Misma situación que gym→hub: el productor publica con SU clase.
    await log.publish(ProducerSidePing('a'),
        causationEventId: 'de-1',
        sourceModule: 'test',
        occurredAt: DateTime.utc(2026, 6, 10));

    expect(projector.seen, ['a'],
        reason: 'el projector casteó a PingPublished sin explotar');
  });

  test('un contrato sin consumidor registrado se persiste sin despachar',
      () async {
    final envelope = await log.publish(OrphanEvent(),
        causationEventId: 'de-1',
        sourceModule: 'test',
        occurredAt: DateTime.utc(2026, 6, 10));

    expect(envelope, isNotNull, reason: 'se publicó (persistió)');
    expect(projector.seen, isEmpty);
    final filas =
        await db.customSelect('SELECT * FROM integration_events').get();
    expect(filas, hasLength(1), reason: 'queda en el log para futuros consumidores');
    expect(await log.readAll().toList(), isEmpty,
        reason: 'replay lo salta mientras nadie lo registre');
  });

  test('readAll devuelve el log en orden con roundtrip completo', () async {
    final occurredAt = DateTime.utc(2026, 6, 10, 18, 30, 0, 0, 123);
    await log.publish(PingPublished('ñandú 💪'),
        causationEventId: 'de-1',
        sourceModule: 'test',
        occurredAt: occurredAt);

    final leidos = await log.readAll().toList();
    expect(leidos, hasLength(1));
    final envelope = leidos.single;
    expect(envelope.sequence, 1);
    expect(envelope.causationEventId, 'de-1');
    expect(envelope.sourceModule, 'test');
    expect(envelope.occurredAt, occurredAt);
    expect((envelope.event as PingPublished).label, 'ñandú 💪');
  });
}
