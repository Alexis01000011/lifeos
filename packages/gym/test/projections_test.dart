import 'package:core/core.dart';
import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
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
      [WorkoutHistoryProjector(db), WorkoutSetsProjector(db)],
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

    Future<List<Map<String, Object?>>> snapshot(String table) async {
      final rows =
          await db.customSelect('SELECT * FROM $table ORDER BY 1, 2').get();
      return rows.map((r) => r.data).toList();
    }

    final historiaAntes = await snapshot(workoutHistoryTable);
    final seriesAntes = await snapshot(gymSetsTable);
    expect(historiaAntes, isNotEmpty);
    expect(seriesAntes, isNotEmpty);

    await engine.rebuild(store.readAll());

    expect(await snapshot(workoutHistoryTable), historiaAntes);
    expect(await snapshot(gymSetsTable), seriesAntes);
  });
}
