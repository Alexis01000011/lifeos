import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryEventStore store;
  late StartWorkoutHandler startHandler;
  late LogSetHandler logSetHandler;
  late CompleteWorkoutHandler completeHandler;

  setUp(() {
    store = InMemoryEventStore();
    final workouts = workoutRepository(store);
    startHandler = StartWorkoutHandler(workouts);
    logSetHandler = LogSetHandler(workouts);
    completeHandler = CompleteWorkoutHandler(workouts);
  });

  test('flujo completo: start → 2 series → complete, todo persistido en '
      'orden', () async {
    await startHandler.handle(StartWorkout('w1'));
    await logSetHandler.handle(LogSet(
        workoutId: 'w1', exercise: 'press banca', weightKg: 60, reps: 8));
    await logSetHandler.handle(LogSet(
        workoutId: 'w1',
        exercise: 'press banca',
        weightKg: 60,
        reps: 7,
        restBeforeSeconds: 150));
    await completeHandler.handle(CompleteWorkout('w1'));

    expect(store.log.map((e) => e.event.eventType), [
      'gym.workout_started',
      'gym.set_logged',
      'gym.set_logged',
      'gym.workout_completed',
    ]);
    expect(store.log.map((e) => e.streamVersion), [1, 2, 3, 4]);
  });

  test('StartWorkout sobre un id existente es rechazado', () async {
    await startHandler.handle(StartWorkout('w1'));
    await expectLater(startHandler.handle(StartWorkout('w1')),
        throwsA(isA<DomainException>()));
  });

  test('LogSet y CompleteWorkout sobre un workout inexistente son '
      'rechazados', () async {
    await expectLater(
      logSetHandler.handle(LogSet(
          workoutId: 'nadie', exercise: 'x', weightKg: 1, reps: 1)),
      throwsA(isA<DomainException>()),
    );
    await expectLater(completeHandler.handle(CompleteWorkout('nadie')),
        throwsA(isA<DomainException>()));
  });

  test('un comando rechazado por el agregado no persiste nada', () async {
    await startHandler.handle(StartWorkout('w1'));

    await expectLater(completeHandler.handle(CompleteWorkout('w1')),
        throwsA(isA<DomainException>()));

    expect(store.log, hasLength(1), reason: 'solo el WorkoutStarted');
  });
}
