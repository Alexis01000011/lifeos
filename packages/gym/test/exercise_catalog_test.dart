import 'package:core/core.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

void main() {
  late ExerciseCatalog catalog;

  setUp(() {
    catalog = ExerciseCatalog(ExerciseCatalog.singletonId);
  });

  group('alta', () {
    test('agrega ejercicio y vincula su propio nombre', () {
      catalog.addExercise(
          exerciseId: 'e1',
          name: 'Press plano (barra)',
          muscleGroup: MuscleGroup.pecho);

      expect(catalog.exerciseCount, 1);
      expect(catalog.currentNameOf('e1'), 'Press plano (barra)');
      expect(catalog.exerciseIdForName('press plano (barra)'), 'e1',
          reason: 'la resolución es case-insensitive');
      expect(catalog.uncommittedEvents.single, isA<ExerciseAdded>());
    });

    test('lleva la modalidad al evento y defaultea a weighted (ADR-0013)',
        () {
      catalog
        ..addExercise(
            exerciseId: 'e1',
            name: 'Plancha',
            muscleGroup: MuscleGroup.abdomen,
            modality: ExerciseModality.bodyweight)
        ..addExercise(
            exerciseId: 'e2',
            name: 'Abdominal curl',
            muscleGroup: MuscleGroup.abdomen);

      final eventos = catalog.uncommittedEvents.cast<ExerciseAdded>();
      expect(eventos.first.modality, ExerciseModality.bodyweight);
      expect(eventos.last.modality, ExerciseModality.weighted);
    });

    test('vincula los legacyNames del alta (ADR-0011)', () {
      catalog.addExercise(
          exerciseId: 'e1',
          name: 'Calf raises (de pie)',
          muscleGroup: MuscleGroup.pierna,
          legacyNames: ['Calves']);

      expect(catalog.exerciseIdForName('calves'), 'e1');
      expect(catalog.exerciseIdForName(' CALVES '), 'e1');
    });

    test('rechaza nombre vacío, id vacío e id repetido', () {
      expect(
          () => catalog.addExercise(
              exerciseId: 'e1', name: '  ', muscleGroup: MuscleGroup.pecho),
          throwsA(isA<DomainException>()));
      expect(
          () => catalog.addExercise(
              exerciseId: ' ', name: 'Aperturas', muscleGroup: MuscleGroup.pecho),
          throwsA(isA<DomainException>()));

      catalog.addExercise(
          exerciseId: 'e1', name: 'Aperturas', muscleGroup: MuscleGroup.pecho);
      expect(
          () => catalog.addExercise(
              exerciseId: 'e1', name: 'Otro', muscleGroup: MuscleGroup.pecho),
          throwsA(isA<DomainException>()));
    });

    test('la unicidad cubre nombres actuales y legacy de OTROS ejercicios '
        '(set-validation: la razón de ser del agregado único)', () {
      catalog.addExercise(
          exerciseId: 'e1',
          name: 'Calf raises',
          muscleGroup: MuscleGroup.pierna,
          legacyNames: ['Calves']);

      // Mismo nombre actual, distinta capitalización.
      expect(
          () => catalog.addExercise(
              exerciseId: 'e2',
              name: 'calf RAISES',
              muscleGroup: MuscleGroup.pierna),
          throwsA(isA<DomainException>()));
      // Nombre que choca con un legacy ajeno.
      expect(
          () => catalog.addExercise(
              exerciseId: 'e2',
              name: 'Calves',
              muscleGroup: MuscleGroup.pierna),
          throwsA(isA<DomainException>()));
      // Legacy que choca con un nombre ajeno.
      expect(
          () => catalog.addExercise(
              exerciseId: 'e2',
              name: 'Gemelos sentado',
              muscleGroup: MuscleGroup.pierna,
              legacyNames: ['calf raises']),
          throwsA(isA<DomainException>()));
    });

    test('rechaza nombres repetidos dentro de la misma alta', () {
      expect(
          () => catalog.addExercise(
              exerciseId: 'e1',
              name: 'Calves',
              muscleGroup: MuscleGroup.pierna,
              legacyNames: ['calves']),
          throwsA(isA<DomainException>()));
    });
  });

  group('rename', () {
    setUp(() {
      catalog.addExercise(
          exerciseId: 'e1',
          name: 'Press plano',
          muscleGroup: MuscleGroup.pecho);
      catalog.addExercise(
          exerciseId: 'e2',
          name: 'Press inclinado',
          muscleGroup: MuscleGroup.pecho);
      catalog.markCommitted();
    });

    test('renombra y el nombre viejo sigue resolviendo al ejercicio', () {
      catalog.renameExercise(
          exerciseId: 'e1', newName: 'Press plano (barra)');

      expect(catalog.currentNameOf('e1'), 'Press plano (barra)');
      expect(catalog.exerciseIdForName('Press plano'), 'e1',
          reason: 'renombrar nunca rompe vínculos (ADR-0011)');
      expect(catalog.exerciseIdForName('press plano (barra)'), 'e1');
    });

    test('el nombre liberado por un rename NO es reutilizable por otro', () {
      catalog.renameExercise(
          exerciseId: 'e1', newName: 'Press plano (barra)');

      expect(
          () => catalog.addExercise(
              exerciseId: 'e3',
              name: 'Press plano',
              muscleGroup: MuscleGroup.pecho),
          throwsA(isA<DomainException>()),
          reason: 'resolvería series viejas de e1 hacia e3');
    });

    test('rechaza renombrar a un nombre ajeno, a vacío o un id inexistente',
        () {
      expect(
          () => catalog.renameExercise(
              exerciseId: 'e1', newName: 'press INCLINADO'),
          throwsA(isA<DomainException>()));
      expect(() => catalog.renameExercise(exerciseId: 'e1', newName: '  '),
          throwsA(isA<DomainException>()));
      expect(
          () => catalog.renameExercise(exerciseId: 'nadie', newName: 'X'),
          throwsA(isA<DomainException>()));
    });

    test('renombrar al mismo nombre exacto es no-op (sin evento)', () {
      catalog.renameExercise(exerciseId: 'e1', newName: 'Press plano');
      expect(catalog.uncommittedEvents, isEmpty);
    });

    test('renombrar solo cambiando capitalización SÍ emite evento', () {
      catalog.renameExercise(exerciseId: 'e1', newName: 'PRESS PLANO');
      expect(catalog.uncommittedEvents.single, isA<ExerciseRenamed>());
      expect(catalog.currentNameOf('e1'), 'PRESS PLANO');
    });
  });

  group('correctModality (compensatorio, ADR-0013)', () {
    test('emite el evento sobre un ejercicio existente y rechaza uno '
        'inexistente', () {
      catalog
        ..addExercise(
            exerciseId: 'e1',
            name: 'Abdominal curl',
            muscleGroup: MuscleGroup.abdomen)
        ..markCommitted()
        ..correctModality(
            exerciseId: 'e1', newModality: ExerciseModality.bodyweight);

      final corregido =
          catalog.uncommittedEvents.single as ExerciseModalityCorrected;
      expect(corregido.exerciseId, 'e1');
      expect(corregido.newModality, ExerciseModality.bodyweight);

      expect(
          () => catalog.correctModality(
              exerciseId: 'nadie', newModality: ExerciseModality.weighted),
          throwsA(isA<DomainException>()));
    });
  });

  test('rehydrate reconstruye el estado (apply puro, sin re-validar)', () {
    final historia = [
      ExerciseAdded(
          exerciseId: 'e1',
          name: 'Calf raises',
          muscleGroup: MuscleGroup.pierna,
          legacyNames: ['Calves']),
      ExerciseRenamed(exerciseId: 'e1', newName: 'Standing calf raise'),
    ];
    var version = 0;
    catalog.rehydrate([
      for (final event in historia)
        EventEnvelope(
          eventId: 'ev${++version}',
          streamId: StreamId(
              ExerciseCatalog.aggregateTypeName, ExerciseCatalog.singletonId),
          streamVersion: version,
          globalSequence: version,
          event: event,
          occurredAt: DateTime.utc(2026, 6, 10),
        ),
    ]);

    expect(catalog.currentNameOf('e1'), 'Standing calf raise');
    expect(catalog.exerciseIdForName('calves'), 'e1');
    expect(catalog.exerciseIdForName('calf raises'), 'e1');
    expect(catalog.exerciseIdForName('standing calf raise'), 'e1');
    expect(catalog.version, 2);
    expect(catalog.uncommittedEvents, isEmpty);
  });
}
