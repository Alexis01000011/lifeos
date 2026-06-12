import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:gym/gym.dart';
import 'package:test/test.dart';

/// Slice vertical del read-side: comandos → DriftEventStore → projectors
/// → tablas reales → GymReadModels. Incluye la prueba ácida oficial.
void main() {
  setUpAll(configureSqliteNativeLibrary);

  late TestDatabase db;
  late ProjectionEngine engine;
  late DriftEventStore store;
  late GymReadModels readModels;
  late StartWorkoutHandler start;
  late LogSetHandler logSet;
  late CompleteWorkoutHandler complete;
  late DiscardWorkoutHandler discard;
  late AddMissedSetHandler addMissed;
  late AddExerciseHandler addExercise;
  late RenameExerciseHandler renameExercise;

  /// Reloj controlado: los tests lo mueven para cruzar semanas.
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 6, 10, 18); // miércoles de pierna
    db = TestDatabase();
    await createEventStoreSchema(db);
    await createGymReadModelSchema(db);

    final registry = DefaultEventTypeRegistry<DomainEvent>();
    registerGymEvents(registry);
    engine = ProjectionEngine(
      [
        WorkoutHistoryProjector(db),
        WorkoutSetsProjector(db),
        ExerciseCatalogProjector(db),
      ],
      DriftProjectionCheckpointStore(db),
    );
    store = DriftEventStore(db, registry, engine, clock: () => now);
    readModels = GymReadModels(db);

    final workouts = workoutRepository(store);
    start = StartWorkoutHandler(workouts);
    logSet = LogSetHandler(workouts);
    complete = CompleteWorkoutHandler(workouts);
    discard = DiscardWorkoutHandler(workouts);
    addMissed = AddMissedSetHandler(workouts);
    final catalogs = exerciseCatalogRepository(store);
    addExercise = AddExerciseHandler(catalogs);
    renameExercise = RenameExerciseHandler(catalogs);
  });

  tearDown(() => db.close());

  /// Día de pierna realista (ver docs/gym_inventario.md).
  Future<void> entrenoDePierna(String id) async {
    await start.handle(StartWorkout(id));
    await logSet.handle(LogSet(
        workoutId: id, exercise: 'sentadilla', weightKg: 80, reps: 10));
    await logSet.handle(LogSet(
        workoutId: id,
        exercise: 'sentadilla',
        weightKg: 80,
        reps: 8,
        restBeforeSeconds: 180));
    await logSet.handle(LogSet(
        workoutId: id, exercise: 'leg press', weightKg: 160, reps: 15));
    await complete.handle(CompleteWorkout(id));
  }

  test('el historial refleja el workout en vivo y al completarlo', () async {
    await start.handle(StartWorkout('w1'));
    await logSet.handle(LogSet(
        workoutId: 'w1', exercise: 'press banca', weightKg: 60, reps: 8));

    var resumen = (await readModels.workoutHistory()).single;
    expect(resumen.isInProgress, isTrue);
    expect(resumen.setCount, 1);
    expect(resumen.totalVolumeKg, 480);

    await logSet.handle(LogSet(
        workoutId: 'w1', exercise: 'press banca', weightKg: 60, reps: 7));
    await complete.handle(CompleteWorkout('w1'));

    resumen = (await readModels.workoutHistory()).single;
    expect(resumen.isInProgress, isFalse);
    expect(resumen.completedAt, now);
    expect(resumen.setCount, 2);
    expect(resumen.totalVolumeKg, 480 + 420);
  });

  test('el volumen semanal bucketiza por semana ISO (lunes)', () async {
    await entrenoDePierna('w1'); // semana del lunes 2026-06-08

    now = DateTime.utc(2026, 6, 13, 10); // sábado, misma semana
    await entrenoDePierna('w2');

    now = DateTime.utc(2026, 6, 15, 18); // lunes siguiente
    await entrenoDePierna('w3');

    final volumenEntreno = 80.0 * 10 + 80 * 8 + 160 * 15; // 3840
    final semanas = await readModels.weeklyVolume();
    expect(semanas, hasLength(2));
    expect(semanas[0].weekStart, '2026-06-15');
    expect(semanas[0].totalVolumeKg, volumenEntreno);
    expect(semanas[1].weekStart, '2026-06-08');
    expect(semanas[1].totalVolumeKg, volumenEntreno * 2);
  });

  test('isoWeekStartUtc: lunes se mapea a sí mismo y domingo a su lunes',
      () {
    expect(isoWeekStartUtc(DateTime.utc(2026, 6, 8)), '2026-06-08');
    expect(isoWeekStartUtc(DateTime.utc(2026, 6, 14, 23, 59)), '2026-06-08');
    expect(isoWeekStartUtc(DateTime.utc(2026, 6, 15)), '2026-06-15');
  });

  test('descartar borra el workout del historial y su volumen de la semana '
      '(ADR-0010)', () async {
    await entrenoDePierna('real');

    // El fantasma completado (caso db99e5a0): series basura para poder salir.
    await start.handle(StartWorkout('fantasma'));
    await logSet.handle(
        LogSet(workoutId: 'fantasma', exercise: 'Ok', weightKg: 0, reps: 1));
    await complete.handle(CompleteWorkout('fantasma'));

    // El fantasma en curso (caso bf0d7bfd): un tap curioso en "Empezar".
    await start.handle(StartWorkout('tap-curioso'));

    expect(await readModels.workoutHistory(), hasLength(3));

    await discard.handle(DiscardWorkout('fantasma'));
    await discard.handle(DiscardWorkout('tap-curioso'));

    final historia = await readModels.workoutHistory();
    expect(historia.single.workoutId, 'real');
    final semanas = await readModels.weeklyVolume();
    expect(semanas.single.totalVolumeKg, 80.0 * 10 + 80 * 8 + 160 * 15,
        reason: 'el volumen del fantasma no deja rastro');
  });

  test('la serie tardía suma al historial y a la semana DEL WORKOUT aunque '
      'la corrección llegue otra semana (ADR-0010)', () async {
    await entrenoDePierna('w1'); // semana del 2026-06-08

    now = DateTime.utc(2026, 6, 16, 9); // martes de la semana siguiente
    await addMissed.handle(AddMissedSet(
        workoutId: 'w1',
        exercise: 'calf raises',
        weightKg: 40,
        reps: 12,
        restBeforeSeconds: 15));

    final resumen = (await readModels.workoutHistory()).single;
    expect(resumen.setCount, 4);
    expect(resumen.totalVolumeKg, 80.0 * 10 + 80 * 8 + 160 * 15 + 40 * 12);

    final semanas = await readModels.weeklyVolume();
    expect(semanas.single.weekStart, '2026-06-08',
        reason: 'la serie pertenece al entreno, no al día de la corrección');
  });

  test('el catálogo proyecta ejercicios y su mapa de nombres, ordenado por '
      'grupo muscular (ADR-0011)', () async {
    await addExercise.handle(AddExercise(
        exerciseId: 'e-press',
        name: 'Press plano (barra)',
        muscleGroup: MuscleGroup.pecho));
    await addExercise.handle(AddExercise(
        exerciseId: 'e-calves',
        name: 'Calf raises',
        muscleGroup: MuscleGroup.pierna,
        legacyNames: ['Calves']));

    final ejercicios = await readModels.exercises();
    expect(ejercicios.map((e) => e.exerciseId), ['e-press', 'e-calves'],
        reason: 'pecho antes que pierna: orden del enum, no alfabético');
    expect(ejercicios.first.muscleGroup, 'pecho');

    // El mapa resuelve nombre actual y legacy, normalizados.
    Future<String?> resolver(String nombre) async {
      final rows = await db.customSelect(
          'SELECT exercise_id FROM $gymExerciseNamesTable '
          'WHERE name_normalized = ?',
          variables: [Variable<String>(nombre.trim().toLowerCase())]).get();
      return rows.isEmpty ? null : rows.single.read<String>('exercise_id');
    }

    expect(await resolver('calves'), 'e-calves');
    expect(await resolver(' CALF RAISES '), 'e-calves');
    expect(await resolver('press plano (barra)'), 'e-press');
    expect(await resolver('inexistente'), isNull);
  });

  test('el rename actualiza el nombre visible y conserva el vínculo viejo '
      '(ADR-0011)', () async {
    await addExercise.handle(AddExercise(
        exerciseId: 'e1',
        name: 'Calf raises',
        muscleGroup: MuscleGroup.pierna));
    await renameExercise.handle(
        RenameExercise(exerciseId: 'e1', newName: 'Standing calf raise'));

    final ejercicio = (await readModels.exercises()).single;
    expect(ejercicio.name, 'Standing calf raise');

    final vinculos = await db
        .customSelect('SELECT name_normalized FROM $gymExerciseNamesTable '
            "WHERE exercise_id = 'e1' ORDER BY name_normalized")
        .get();
    expect(vinculos.map((r) => r.read<String>('name_normalized')),
        ['calf raises', 'standing calf raise']);
  });

  test('una serie corporal guarda weight_kg null y aporta solo su lastre '
      'al volumen (ADR-0013)', () async {
    await addExercise.handle(AddExercise(
        exerciseId: 'e1',
        name: 'Plancha',
        muscleGroup: MuscleGroup.abdomen,
        modality: ExerciseModality.bodyweight));
    await start.handle(StartWorkout('w1'));
    await logSet.handle(LogSet(
        workoutId: 'w1', exercise: 'Plancha', exerciseId: 'e1', reps: 12));
    await logSet.handle(LogSet(
        workoutId: 'w1',
        exercise: 'Plancha',
        exerciseId: 'e1',
        weightKg: 5,
        reps: 10));

    final resumen = (await readModels.workoutHistory()).single;
    expect(resumen.setCount, 2);
    expect(resumen.totalVolumeKg, 50,
        reason: 'solo el lastre cuenta como carga externa');

    final series = await readModels.setsForWorkout('w1');
    expect(series.first.weightKg, isNull);
    expect(series.first.isBodyweight, isTrue,
        reason: 'la modalidad llega por el join al catálogo');
    expect(series.last.weightKg, 5);

    final semana = (await readModels.weeklyVolume()).single;
    expect(semana.totalVolumeKg, 50,
        reason: 'el COALESCE evita que el null anule la suma');

    final ultimo = await readModels.lastSetForExercise('e1');
    expect(ultimo, isNotNull);
    expect(ultimo!.weightKg, 5);
  });

  test('la modalidad se proyecta en el catálogo y el compensatorio la '
      'corrige (ADR-0013)', () async {
    await addExercise.handle(AddExercise(
        exerciseId: 'e1',
        name: 'Abdominal curl',
        muscleGroup: MuscleGroup.abdomen));
    expect((await readModels.exercises()).single.modality, 'weighted');

    await CorrectExerciseModalityHandler(exerciseCatalogRepository(store))
        .handle(CorrectExerciseModality(
            exerciseId: 'e1', newModality: ExerciseModality.bodyweight));
    final corregido = (await readModels.exercises()).single;
    expect(corregido.modality, 'bodyweight');
    expect(corregido.isBodyweight, isTrue);
  });

  test('migración de forma (ADR-0013): la tabla de series con weight_kg '
      'NOT NULL se tira y el checkpoint viejo se limpia', () async {
    final legacyDb = TestDatabase();
    addTearDown(legacyDb.close);
    await createEventStoreSchema(legacyDb);
    // La forma pre-ADR-0013, como existe hoy en el A71.
    await legacyDb.customStatement('''
      CREATE TABLE $gymSetsTable (
        workout_id          TEXT    NOT NULL,
        position            INTEGER NOT NULL,
        exercise            TEXT    NOT NULL,
        weight_kg           REAL    NOT NULL,
        reps                INTEGER NOT NULL,
        rest_before_seconds INTEGER,
        week_start          TEXT    NOT NULL,
        is_late             INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (workout_id, position)
      )
    ''');
    await legacyDb.customStatement(
        "INSERT INTO $gymSetsTable VALUES ('w1', 1, 'x', 80, 10, NULL, '2026-06-08', 0)");
    await legacyDb.customStatement(
        "INSERT INTO projection_checkpoints VALUES ('gym.workout_sets', 30)");

    await createGymReadModelSchema(legacyDb);

    final notNull = await legacyDb
        .customSelect("SELECT 1 FROM pragma_table_info('$gymSetsTable') "
            "WHERE name = 'weight_kg' AND \"notnull\" = 1")
        .get();
    expect(notNull, isEmpty, reason: 'la columna quedó nullable');
    final filas =
        await legacyDb.customSelect('SELECT * FROM $gymSetsTable').get();
    expect(filas, isEmpty,
        reason: 'la tabla renació vacía: el catch-up la backfillea');
    final checkpoints = await legacyDb
        .customSelect('SELECT * FROM projection_checkpoints')
        .get();
    expect(checkpoints, isEmpty, reason: 'el checkpoint viejo se limpió');

    // Idempotencia: una segunda pasada no vuelve a tirar nada.
    await legacyDb.customStatement(
        "INSERT INTO $gymSetsTable (workout_id, position, exercise, weight_kg, reps, week_start) "
        "VALUES ('w1', 1, 'Plancha', NULL, 12, '2026-06-08')");
    await createGymReadModelSchema(legacyDb);
    expect(
        await legacyDb.customSelect('SELECT * FROM $gymSetsTable').get(),
        hasLength(1));
  });

  test('PRUEBA ÁCIDA: reset de proyecciones + replay = estado idéntico',
      () async {
    await entrenoDePierna('w1');
    now = DateTime.utc(2026, 6, 15, 18);
    await entrenoDePierna('w2');
    await start.handle(StartWorkout('w3')); // uno en curso, sin completar
    await logSet.handle(LogSet(
        workoutId: 'w3', exercise: 'press militar', weightKg: 40, reps: 8));
    // Historia compensatoria incluida: el replay también la reproduce.
    await discard.handle(DiscardWorkout('w2'));
    now = DateTime.utc(2026, 6, 16, 9);
    await addMissed.handle(AddMissedSet(
        workoutId: 'w1', exercise: 'calf raises', weightKg: 40, reps: 12));
    // Historia del catálogo incluida (ADR-0011): alta con legacy y rename.
    await addExercise.handle(AddExercise(
        exerciseId: 'e1',
        name: 'Calf raises',
        muscleGroup: MuscleGroup.pierna,
        legacyNames: ['Calves']));
    await renameExercise.handle(
        RenameExercise(exerciseId: 'e1', newName: 'Standing calf raise'));
    // Historia bodyweight incluida (ADR-0013): alta corporal, serie sin
    // carga externa y corrección de modalidad.
    await addExercise.handle(AddExercise(
        exerciseId: 'e2',
        name: 'Plancha',
        muscleGroup: MuscleGroup.abdomen,
        modality: ExerciseModality.bodyweight));
    await logSet.handle(LogSet(
        workoutId: 'w3', exercise: 'Plancha', exerciseId: 'e2', reps: 12));
    await CorrectExerciseModalityHandler(exerciseCatalogRepository(store))
        .handle(CorrectExerciseModality(
            exerciseId: 'e1', newModality: ExerciseModality.weighted));

    Future<List<Map<String, Object?>>> snapshot(String table) async {
      final rows =
          await db.customSelect('SELECT * FROM $table ORDER BY 1, 2').get();
      return rows.map((r) => r.data).toList();
    }

    final tablas = [
      workoutHistoryTable,
      gymSetsTable,
      gymExercisesTable,
      gymExerciseNamesTable,
    ];
    final antes = {for (final t in tablas) t: await snapshot(t)};
    for (final t in tablas) {
      expect(antes[t], isNotEmpty, reason: '$t debería tener filas');
    }

    await engine.rebuild(store.readAll());

    for (final t in tablas) {
      expect(await snapshot(t), antes[t], reason: '$t debe calcar al vivo');
    }
  });
}
