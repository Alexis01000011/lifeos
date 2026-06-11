import 'package:core/core.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

void main() {
  late DefaultEventTypeRegistry<DomainEvent> registry;

  setUp(() {
    registry = DefaultEventTypeRegistry<DomainEvent>();
    registerGymEvents(registry);
  });

  DomainEvent roundtrip(DomainEvent event) =>
      registry.deserialize(event.eventType, event.schemaVersion, event.toJson());

  test('SetLogged sobrevive el roundtrip completo', () {
    final leido = roundtrip(SetLogged(
      exercise: 'peso muerto',
      weightKg: 102.5,
      reps: 3,
      restBeforeSeconds: 180,
    )) as SetLogged;

    expect(leido.exercise, 'peso muerto');
    expect(leido.weightKg, 102.5);
    expect(leido.reps, 3);
    expect(leido.restBeforeSeconds, 180);
  });

  test('SetLogged sin descanso: el campo ausente deserializa a null '
      '(weak schema)', () {
    final leido = roundtrip(
            SetLogged(exercise: 'dominadas', weightKg: 0, reps: 10))
        as SetLogged;
    expect(leido.restBeforeSeconds, isNull);
  });

  test('los eventos de ciclo de vida sobreviven el roundtrip', () {
    expect(roundtrip(WorkoutStarted()), isA<WorkoutStarted>());
    expect(roundtrip(WorkoutCompleted()), isA<WorkoutCompleted>());
  });

  test('WorkoutDiscarded sobrevive el roundtrip y defaultea wasCompleted '
      'a false (weak schema)', () {
    final leido =
        roundtrip(WorkoutDiscarded(wasCompleted: true)) as WorkoutDiscarded;
    expect(leido.wasCompleted, isTrue);

    final sinCampo = registry.deserialize(WorkoutDiscarded.type, 1, const {})
        as WorkoutDiscarded;
    expect(sinCampo.wasCompleted, isFalse);
  });

  test('SetLoggedLate sobrevive el roundtrip (con y sin descanso)', () {
    final leido = roundtrip(SetLoggedLate(
      exercise: 'calf raises',
      weightKg: 40,
      reps: 12,
      restBeforeSeconds: 15,
    )) as SetLoggedLate;
    expect(leido.exercise, 'calf raises');
    expect(leido.weightKg, 40);
    expect(leido.reps, 12);
    expect(leido.restBeforeSeconds, 15);

    final sinDescanso = roundtrip(
            SetLoggedLate(exercise: 'calf raises', weightKg: 40, reps: 12))
        as SetLoggedLate;
    expect(sinDescanso.restBeforeSeconds, isNull);
  });

  test('SetLogged y SetLoggedLate llevan exerciseId y defaultean a null '
      'en eventos pre-catálogo (weak schema, ADR-0011)', () {
    final conId = roundtrip(SetLogged(
        exercise: 'Calves', exerciseId: 'e1', weightKg: 40, reps: 12))
        as SetLogged;
    expect(conId.exerciseId, 'e1');

    final tardiaConId = roundtrip(SetLoggedLate(
        exercise: 'Calves', exerciseId: 'e1', weightKg: 40, reps: 12))
        as SetLoggedLate;
    expect(tardiaConId.exerciseId, 'e1');

    // El JSON persistido antes del catálogo no trae el campo.
    final viejo = registry.deserialize(SetLogged.type, 1,
        const {'exercise': 'Calves', 'weightKg': 40, 'reps': 12}) as SetLogged;
    expect(viejo.exerciseId, isNull);
    expect(viejo.exercise, 'Calves');
  });

  test('ExerciseAdded sobrevive el roundtrip y defaultea legacyNames a '
      'lista vacía (weak schema)', () {
    final leido = roundtrip(ExerciseAdded(
      exerciseId: 'e1',
      name: 'Calf raises',
      muscleGroup: MuscleGroup.pierna,
      legacyNames: ['Calves'],
    )) as ExerciseAdded;
    expect(leido.exerciseId, 'e1');
    expect(leido.name, 'Calf raises');
    expect(leido.muscleGroup, MuscleGroup.pierna);
    expect(leido.legacyNames, ['Calves']);

    final sinLegacy = registry.deserialize(ExerciseAdded.type, 1, const {
      'exerciseId': 'e2',
      'name': 'Press plano',
      'muscleGroup': 'pecho',
    }) as ExerciseAdded;
    expect(sinLegacy.legacyNames, isEmpty);
  });

  test('ExerciseRenamed sobrevive el roundtrip', () {
    final leido = roundtrip(
            ExerciseRenamed(exerciseId: 'e1', newName: 'Standing calf raise'))
        as ExerciseRenamed;
    expect(leido.exerciseId, 'e1');
    expect(leido.newName, 'Standing calf raise');
  });

  test('el grupo muscular viaja como string estable (name del enum, '
      'nunca el índice)', () {
    final json = ExerciseAdded(
            exerciseId: 'e1', name: 'Curl', muscleGroup: MuscleGroup.biceps)
        .toJson();
    expect(json['muscleGroup'], 'biceps');
  });

  test('los eventType son estables (contrato de persistencia)', () {
    expect(WorkoutStarted.type, 'gym.workout_started');
    expect(SetLogged.type, 'gym.set_logged');
    expect(WorkoutCompleted.type, 'gym.workout_completed');
    expect(WorkoutDiscarded.type, 'gym.workout_discarded');
    expect(SetLoggedLate.type, 'gym.set_logged_late');
    expect(ExerciseAdded.type, 'gym.exercise_added');
    expect(ExerciseRenamed.type, 'gym.exercise_renamed');
  });
}
