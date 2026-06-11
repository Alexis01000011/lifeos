import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryEventStore store;
  late StartWorkoutHandler startHandler;
  late LogSetHandler logSetHandler;
  late CompleteWorkoutHandler completeHandler;
  late DiscardWorkoutHandler discardHandler;
  late AddMissedSetHandler addMissedSetHandler;

  setUp(() {
    store = InMemoryEventStore();
    final workouts = workoutRepository(store);
    startHandler = StartWorkoutHandler(workouts);
    logSetHandler = LogSetHandler(workouts);
    completeHandler = CompleteWorkoutHandler(workouts);
    discardHandler = DiscardWorkoutHandler(workouts);
    addMissedSetHandler = AddMissedSetHandler(workouts);
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

  test('flujo compensatorio: descartar un fantasma y reponer una serie '
      'olvidada (ADR-0010)', () async {
    // El fantasma en curso (caso bf0d7bfd): empezado por error, se descarta.
    await startHandler.handle(StartWorkout('fantasma'));
    await discardHandler.handle(DiscardWorkout('fantasma'));

    // El entreno real completado al que le faltó la serie de calves.
    await startHandler.handle(StartWorkout('real'));
    await logSetHandler.handle(LogSet(
        workoutId: 'real', exercise: 'calf raises', weightKg: 70, reps: 10));
    await completeHandler.handle(CompleteWorkout('real'));
    await addMissedSetHandler.handle(AddMissedSet(
        workoutId: 'real',
        exercise: 'calf raises',
        weightKg: 40,
        reps: 12,
        restBeforeSeconds: 15));

    expect(store.log.map((e) => e.event.eventType), [
      'gym.workout_started',
      'gym.workout_discarded',
      'gym.workout_started',
      'gym.set_logged',
      'gym.workout_completed',
      'gym.set_logged_late',
    ]);
  });

  test('DiscardWorkout y AddMissedSet sobre un workout inexistente son '
      'rechazados', () async {
    await expectLater(discardHandler.handle(DiscardWorkout('nadie')),
        throwsA(isA<DomainException>()));
    await expectLater(
      addMissedSetHandler.handle(AddMissedSet(
          workoutId: 'nadie', exercise: 'x', weightKg: 1, reps: 1)),
      throwsA(isA<DomainException>()),
    );
  });

  test('un comando rechazado por el agregado no persiste nada', () async {
    await startHandler.handle(StartWorkout('w1'));

    await expectLater(completeHandler.handle(CompleteWorkout('w1')),
        throwsA(isA<DomainException>()));

    expect(store.log, hasLength(1), reason: 'solo el WorkoutStarted');
  });

  group('catálogo (ADR-0011)', () {
    late AddExerciseHandler addExerciseHandler;
    late RenameExerciseHandler renameExerciseHandler;

    setUp(() {
      final catalogs = exerciseCatalogRepository(store);
      addExerciseHandler = AddExerciseHandler(catalogs);
      renameExerciseHandler = RenameExerciseHandler(catalogs);
    });

    test('el primer alta crea el singleton; las siguientes lo cargan '
        '(load-or-create)', () async {
      await addExerciseHandler.handle(AddExercise(
          exerciseId: 'e1',
          name: 'Leg press',
          muscleGroup: MuscleGroup.pierna));
      await addExerciseHandler.handle(AddExercise(
          exerciseId: 'e2',
          name: 'Calf raises',
          muscleGroup: MuscleGroup.pierna,
          legacyNames: ['Calves']));
      await renameExerciseHandler.handle(RenameExercise(
          exerciseId: 'e2', newName: 'Standing calf raise'));

      expect(store.log.map((e) => e.event.eventType), [
        'gym.exercise_added',
        'gym.exercise_added',
        'gym.exercise_renamed',
      ]);
      expect(store.log.map((e) => e.streamVersion), [1, 2, 3],
          reason: 'un solo stream: el catálogo es singleton');
      expect(
          store.log.map((e) => e.streamId.aggregateId).toSet(),
          {ExerciseCatalog.singletonId});
    });

    test('la invariante de unicidad sobrevive entre comandos (rehidratación '
        'desde eventos, no memoria compartida)', () async {
      await addExerciseHandler.handle(AddExercise(
          exerciseId: 'e1',
          name: 'Leg press',
          muscleGroup: MuscleGroup.pierna));

      await expectLater(
        addExerciseHandler.handle(AddExercise(
            exerciseId: 'e2',
            name: 'LEG PRESS',
            muscleGroup: MuscleGroup.pierna)),
        throwsA(isA<DomainException>()),
      );
      expect(store.log, hasLength(1));
    });

    test('renombrar sobre catálogo vacío o ejercicio inexistente es '
        'rechazado', () async {
      await expectLater(
        renameExerciseHandler
            .handle(RenameExercise(exerciseId: 'e1', newName: 'X')),
        throwsA(isA<DomainException>()),
      );

      await addExerciseHandler.handle(AddExercise(
          exerciseId: 'e1',
          name: 'Leg press',
          muscleGroup: MuscleGroup.pierna));
      await expectLater(
        renameExerciseHandler
            .handle(RenameExercise(exerciseId: 'nadie', newName: 'X')),
        throwsA(isA<DomainException>()),
      );
    });

    test('LogSet lleva el exerciseId hasta el evento persistido', () async {
      await addExerciseHandler.handle(AddExercise(
          exerciseId: 'e1',
          name: 'Leg press',
          muscleGroup: MuscleGroup.pierna));
      await startHandler.handle(StartWorkout('w1'));
      await logSetHandler.handle(LogSet(
          workoutId: 'w1',
          exercise: 'Leg press',
          exerciseId: 'e1',
          weightKg: 180,
          reps: 10));

      final serie = store.log.last.event as SetLogged;
      expect(serie.exerciseId, 'e1');
      expect(serie.exercise, 'Leg press');
    });
  });
}
