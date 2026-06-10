import 'package:core/core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late RecordingProjector gymHistory;
  late RecordingProjector hubStats;
  late InMemoryCheckpointStore checkpoints;
  late ProjectionEngine engine;

  setUp(() {
    gymHistory = RecordingProjector('gym.history', {'gym.workout_logged'});
    hubStats = RecordingProjector('hub.stats', {'gym.workout_logged', 'days.rated'});
    checkpoints = InMemoryCheckpointStore();
    engine = ProjectionEngine([gymHistory, hubStats], checkpoints);
  });

  test('despacha solo a los projectors que declaran el eventType', () async {
    await engine.project(
        envelope(TestEvent('days.rated', 'x'), globalSequence: 1));

    expect(gymHistory.projected, isEmpty);
    expect(hubStats.projected, ['evt-1']);
  });

  test('avanza el checkpoint solo del projector que manejó el evento',
      () async {
    await engine.project(
        envelope(TestEvent('days.rated', 'x'), globalSequence: 1));

    expect(checkpoints.checkpoints['hub.stats'], 1);
    expect(checkpoints.checkpoints.containsKey('gym.history'), isFalse);
  });

  test('es idempotente: un envelope ya proyectado se salta', () async {
    final e = envelope(TestEvent('gym.workout_logged', 'x'), globalSequence: 1);
    await engine.project(e);
    await engine.project(e);

    expect(gymHistory.projected, ['evt-1']);
    expect(hubStats.projected, ['evt-1']);
  });

  test('projectAll respeta el orden de los envelopes', () async {
    await engine.projectAll([
      envelope(TestEvent('gym.workout_logged', 'a'), globalSequence: 1),
      envelope(TestEvent('gym.workout_logged', 'b'),
          globalSequence: 2, streamVersion: 2),
    ]);

    expect(gymHistory.projected, ['evt-1', 'evt-2']);
  });

  test('rebuild = reset + replay deja el mismo estado (prueba ácida)',
      () async {
    final history = [
      envelope(TestEvent('gym.workout_logged', 'a'), globalSequence: 1),
      envelope(TestEvent('days.rated', 'b'), globalSequence: 2),
      envelope(TestEvent('gym.workout_logged', 'c'),
          globalSequence: 3, streamVersion: 2),
    ];
    await engine.projectAll(history);
    final estadoAntes = [
      List.of(gymHistory.projected),
      List.of(hubStats.projected),
    ];

    await engine.rebuild(Stream.fromIterable(history));

    expect([gymHistory.projected, hubStats.projected], estadoAntes);
    expect(checkpoints.checkpoints['gym.history'], 3);
    expect(checkpoints.checkpoints['hub.stats'], 3);
  });
}
