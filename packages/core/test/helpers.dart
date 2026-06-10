import 'dart:async';

import 'package:core/core.dart';

/// Evento de juguete para tests del core.
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

EventEnvelope envelope(
  DomainEvent event, {
  required int globalSequence,
  String aggregateId = 'a1',
  int streamVersion = 1,
}) =>
    EventEnvelope(
      eventId: 'evt-$globalSequence',
      streamId: StreamId('test.aggregate', aggregateId),
      streamVersion: streamVersion,
      globalSequence: globalSequence,
      occurredAt: DateTime.utc(2026, 6, 10),
      event: event,
    );

/// Projector en memoria: acumula los eventIds que proyectó.
class RecordingProjector implements Projector {
  @override
  final String name;
  @override
  final Set<String> handledEventTypes;

  final List<String> projected = [];

  RecordingProjector(this.name, this.handledEventTypes);

  @override
  FutureOr<void> project(EventEnvelope envelope) {
    projected.add(envelope.eventId);
  }

  @override
  Future<void> reset() async => projected.clear();
}

class InMemoryCheckpointStore implements ProjectionCheckpointStore {
  final Map<String, int> checkpoints = {};

  @override
  Future<int> getCheckpoint(String projectorName) async =>
      checkpoints[projectorName] ?? 0;

  @override
  Future<void> saveCheckpoint(String projectorName, int globalSequence) async {
    checkpoints[projectorName] = globalSequence;
  }
}
