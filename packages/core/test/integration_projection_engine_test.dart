import 'package:core/core.dart';
import 'package:test/test.dart';

class FakeIntegrationEvent implements IntegrationEvent {
  @override
  final String eventType;
  FakeIntegrationEvent(this.eventType);

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {};
}

class RecordingIntegrationProjector implements IntegrationProjector {
  @override
  final String name;
  @override
  final Set<String> handledEventTypes;
  final List<int> projected = [];
  var resets = 0;

  RecordingIntegrationProjector(this.name, this.handledEventTypes);

  @override
  Future<void> project(IntegrationEventEnvelope envelope) async {
    projected.add(envelope.sequence);
  }

  @override
  Future<void> reset() async => resets++;
}

class InMemoryCheckpoints implements ProjectionCheckpointStore {
  final Map<String, int> _checkpoints = {};

  @override
  Future<int> getCheckpoint(String projectorName) async =>
      _checkpoints[projectorName] ?? 0;

  @override
  Future<void> saveCheckpoint(String projectorName, int globalSequence) async =>
      _checkpoints[projectorName] = globalSequence;
}

IntegrationEventEnvelope envelope(int sequence, String type) =>
    IntegrationEventEnvelope(
      sequence: sequence,
      eventId: 'ie-$sequence',
      causationEventId: 'de-$sequence',
      sourceModule: 'gym',
      occurredAt: DateTime.utc(2026, 6, 10),
      event: FakeIntegrationEvent(type),
    );

void main() {
  test('despacha por eventType y la guarda de checkpoint evita re-proyectar',
      () async {
    final interesado =
        RecordingIntegrationProjector('hub.a', {'gym.workout_completed'});
    final ajeno = RecordingIntegrationProjector('hub.b', {'otro.tipo'});
    final engine =
        IntegrationProjectionEngine([interesado, ajeno], InMemoryCheckpoints());

    await engine.project(envelope(1, 'gym.workout_completed'));
    await engine.project(envelope(1, 'gym.workout_completed')); // replay
    await engine.project(envelope(2, 'gym.workout_completed'));

    expect(interesado.projected, [1, 2]);
    expect(ajeno.projected, isEmpty);
  });

  test('rebuild resetea y reproyecta desde cero', () async {
    final projector =
        RecordingIntegrationProjector('hub.a', {'gym.workout_completed'});
    final engine =
        IntegrationProjectionEngine([projector], InMemoryCheckpoints());

    await engine.project(envelope(1, 'gym.workout_completed'));
    await engine.project(envelope(2, 'gym.workout_completed'));

    await engine.rebuild(Stream.fromIterable(
        [envelope(1, 'gym.workout_completed'), envelope(2, 'gym.workout_completed')]));

    expect(projector.resets, 1);
    expect(projector.projected, [1, 2, 1, 2]);
  });
}
