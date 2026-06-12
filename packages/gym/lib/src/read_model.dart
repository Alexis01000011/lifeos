import 'package:drift/drift.dart';

import 'events.dart';

/// Read model del módulo (ADR-0008): tablas propias creadas con SQL crudo
/// sobre la database compuesta. Nadie fuera de gym lee estas tablas.

const workoutHistoryTable = 'gym_workout_history';
const gymSetsTable = 'gym_sets';
const gymExercisesTable = 'gym_exercises';
const gymExerciseNamesTable = 'gym_exercise_names';

/// Idempotente; la app shell lo llama en su arranque, junto con
/// createEventStoreSchema. Las tablas son desechables por contrato:
/// reset + replay las reconstruye (prueba ácida).
Future<void> createGymReadModelSchema(GeneratedDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $workoutHistoryTable (
      workout_id      TEXT    NOT NULL PRIMARY KEY,
      started_at      INTEGER NOT NULL,
      completed_at    INTEGER,
      set_count       INTEGER NOT NULL DEFAULT 0,
      total_volume_kg REAL    NOT NULL DEFAULT 0
    )
  ''');
  // Migración de forma (ADR-0013): weight_kg pasó a nullable y SQLite no
  // relaja un NOT NULL sin rebuild. Las tablas de lectura son desechables
  // por contrato: si se detecta la forma vieja, la tabla se tira y el
  // projector renacido ('gym.workout_sets_v2', checkpoint 0) deja que el
  // catch-up del arranque la reconstruya desde los eventos.
  final legacySets = await db
      .customSelect(
        "SELECT 1 FROM pragma_table_info('$gymSetsTable') "
        "WHERE name = 'weight_kg' AND \"notnull\" = 1",
      )
      .get();
  if (legacySets.isNotEmpty) {
    await db.customStatement('DROP TABLE $gymSetsTable');
    await db.customStatement(
        "DELETE FROM projection_checkpoints WHERE projector_name = 'gym.workout_sets'");
  }
  // Granular (ADR-0010): una fila por serie; el volumen semanal es un
  // GROUP BY en la consulta. Así el descarte es un DELETE y no hay
  // acumulador que no sepa restar. Es además la base del detalle de
  // entreno y las estadísticas de progresión del Hito 2.
  // weight_kg nullable (ADR-0013): null = sin carga externa.
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $gymSetsTable (
      workout_id          TEXT    NOT NULL,
      position            INTEGER NOT NULL,
      exercise            TEXT    NOT NULL,
      weight_kg           REAL,
      reps                INTEGER NOT NULL,
      rest_before_seconds INTEGER,
      week_start          TEXT    NOT NULL,
      is_late             INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (workout_id, position)
    )
  ''');
  // Catálogo de ejercicios (ADR-0011): una fila por ejercicio, más el mapa
  // de nombres (actuales + históricos + legacy, normalizados) con el que
  // las consultas resuelven las series registradas a texto libre.
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $gymExercisesTable (
      exercise_id  TEXT NOT NULL PRIMARY KEY,
      name         TEXT NOT NULL,
      muscle_group TEXT NOT NULL,
      modality     TEXT NOT NULL DEFAULT 'weighted'
    )
  ''');
  // Modalidad (ADR-0013): agregar columna con default no exige rebuild;
  // las filas existentes quedan 'weighted', correcto para todas.
  final hasModality = await db
      .customSelect(
        "SELECT 1 FROM pragma_table_info('$gymExercisesTable') "
        "WHERE name = 'modality'",
      )
      .get();
  if (hasModality.isEmpty) {
    await db.customStatement(
        "ALTER TABLE $gymExercisesTable ADD COLUMN modality TEXT NOT NULL DEFAULT 'weighted'");
  }
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $gymExerciseNamesTable (
      name_normalized TEXT NOT NULL PRIMARY KEY,
      exercise_id     TEXT NOT NULL
    )
  ''');
  // Acumulador reemplazado por gym_sets (ADR-0010). Las tablas de lectura
  // son desechables por contrato, así que el viejo se elimina sin migrar.
  await db.customStatement('DROP TABLE IF EXISTS gym_weekly_volume');
}

/// Resumen de un workout para la pantalla de historial.
class WorkoutSummary {
  final String workoutId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int setCount;
  final double totalVolumeKg;

  WorkoutSummary({
    required this.workoutId,
    required this.startedAt,
    required this.completedAt,
    required this.setCount,
    required this.totalVolumeKg,
  });

  bool get isInProgress => completedAt == null;
}

/// Volumen total (kg×reps) de una semana ISO; [weekStart] es el lunes en
/// formato YYYY-MM-DD.
class WeeklyVolume {
  final String weekStart;
  final double totalVolumeKg;

  WeeklyVolume({required this.weekStart, required this.totalVolumeKg});
}

/// Un ejercicio del catálogo, para el picker y la pantalla de catálogo.
class ExerciseSummary {
  final String exerciseId;
  final String name;
  final String muscleGroup;

  /// 'weighted' | 'bodyweight' (ADR-0013), string estable del enum.
  final String modality;

  ExerciseSummary({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.modality = 'weighted',
  });

  bool get isBodyweight => modality == ExerciseModality.bodyweight.name;
}

/// Una serie de un entreno, para el mini-registro en vivo y el detalle de
/// un entreno pasado.
class SetSummary {
  final int position;
  final String exercise;

  /// null = sin carga externa (ADR-0013).
  final double? weightKg;
  final int reps;
  final int? restBeforeSeconds;
  final bool isLate;

  /// Modalidad del ejercicio resuelta por el mapa de nombres; null si la
  /// serie no se pudo vincular al catálogo.
  final String? modality;

  SetSummary({
    required this.position,
    required this.exercise,
    required this.weightKg,
    required this.reps,
    required this.restBeforeSeconds,
    required this.isLate,
    this.modality,
  });

  bool get isBodyweight => modality == ExerciseModality.bodyweight.name;
}

/// API de consulta del módulo. La UI (Fase 3) la envuelve en providers;
/// la reactividad se arma con tableUpdates sobre los nombres de tabla.
class GymReadModels {
  final GeneratedDatabase _db;

  GymReadModels(this._db);

  Future<List<WorkoutSummary>> workoutHistory() async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM $workoutHistoryTable ORDER BY started_at DESC')
        .get();
    return [
      for (final row in rows)
        WorkoutSummary(
          workoutId: row.read<String>('workout_id'),
          startedAt: DateTime.fromMicrosecondsSinceEpoch(
              row.read<int>('started_at'),
              isUtc: true),
          completedAt: switch (row.readNullable<int>('completed_at')) {
            null => null,
            final micros =>
              DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true),
          },
          setCount: row.read<int>('set_count'),
          totalVolumeKg: row.read<double>('total_volume_kg'),
        ),
    ];
  }

  /// Catálogo completo, ordenado por grupo muscular (orden del enum, que
  /// es el de la rutina real) y nombre.
  Future<List<ExerciseSummary>> exercises() async {
    final rows = await _db
        .customSelect('SELECT * FROM $gymExercisesTable ORDER BY name')
        .get();
    final summaries = [
      for (final row in rows)
        ExerciseSummary(
          exerciseId: row.read<String>('exercise_id'),
          name: row.read<String>('name'),
          muscleGroup: row.read<String>('muscle_group'),
          modality: row.read<String>('modality'),
        ),
    ];
    final groupOrder = {
      for (final (i, g) in MuscleGroup.values.indexed) g.name: i,
    };
    summaries.sort((a, b) {
      final byGroup = (groupOrder[a.muscleGroup] ?? 99)
          .compareTo(groupOrder[b.muscleGroup] ?? 99);
      return byGroup != 0 ? byGroup : a.name.compareTo(b.name);
    });
    return summaries;
  }

  Future<List<WeeklyVolume>> weeklyVolume() async {
    // COALESCE: una serie sin carga externa (ADR-0013) aporta 0, no anula
    // la suma de la semana.
    final rows = await _db
        .customSelect(
            'SELECT week_start, SUM(COALESCE(weight_kg, 0) * reps) AS total_volume_kg '
            'FROM $gymSetsTable GROUP BY week_start ORDER BY week_start DESC')
        .get();
    return [
      for (final row in rows)
        WeeklyVolume(
          weekStart: row.read<String>('week_start'),
          totalVolumeKg: row.read<double>('total_volume_kg'),
        ),
    ];
  }

  /// Último peso y reps del ejercicio dado (por ejerciseId). Usa el mapa de
  /// nombres para cubrir series registradas bajo nombres históricos o legacy.
  /// Devuelve null si el ejercicio nunca fue registrado; weightKg null =
  /// la última serie fue sin carga externa (ADR-0013).
  Future<({double? weightKg, int reps})?> lastSetForExercise(
      String exerciseId) async {
    final rows = await _db.customSelect(
      'SELECT gs.weight_kg, gs.reps '
      'FROM $gymSetsTable gs '
      'INNER JOIN $gymExerciseNamesTable gen '
      '  ON gen.name_normalized = lower(trim(gs.exercise)) '
      'INNER JOIN $workoutHistoryTable gwh '
      '  ON gwh.workout_id = gs.workout_id '
      'WHERE gen.exercise_id = ? '
      'ORDER BY gwh.started_at DESC, gs.position DESC '
      'LIMIT 1',
      variables: [Variable.withString(exerciseId)],
    ).get();
    if (rows.isEmpty) return null;
    return (
      weightKg: rows.first.readNullable<double>('weight_kg'),
      reps: rows.first.read<int>('reps'),
    );
  }

  /// Top N ejercicios por número de series registradas. Alimenta la sección
  /// "Frecuentes" del picker. Devuelve lista vacía si no hay series aún.
  Future<List<ExerciseSummary>> exercisesByFrequency({int limit = 5}) async {
    final rows = await _db.customSelect(
      'SELECT e.exercise_id, e.name, e.muscle_group, e.modality, '
      '       COUNT(*) AS use_count '
      'FROM $gymSetsTable gs '
      'INNER JOIN $gymExerciseNamesTable gen '
      '  ON gen.name_normalized = lower(trim(gs.exercise)) '
      'INNER JOIN $gymExercisesTable e '
      '  ON e.exercise_id = gen.exercise_id '
      'GROUP BY e.exercise_id, e.name, e.muscle_group, e.modality '
      'ORDER BY use_count DESC '
      'LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        ExerciseSummary(
          exerciseId: row.read<String>('exercise_id'),
          name: row.read<String>('name'),
          muscleGroup: row.read<String>('muscle_group'),
          modality: row.read<String>('modality'),
        ),
    ];
  }

  Future<List<SetSummary>> setsForWorkout(String workoutId) async {
    // LEFT JOIN al catálogo vía el mapa de nombres: trae la modalidad para
    // que la UI distinga carga de lastre (ADR-0013). Una serie sin vínculo
    // queda con modalidad null.
    final rows = await _db
        .customSelect(
          'SELECT gs.*, e.modality AS modality '
          'FROM $gymSetsTable gs '
          'LEFT JOIN $gymExerciseNamesTable gen '
          '  ON gen.name_normalized = lower(trim(gs.exercise)) '
          'LEFT JOIN $gymExercisesTable e '
          '  ON e.exercise_id = gen.exercise_id '
          'WHERE gs.workout_id = ? ORDER BY gs.position',
          variables: [Variable.withString(workoutId)],
        )
        .get();
    return [
      for (final row in rows)
        SetSummary(
          position: row.read<int>('position'),
          exercise: row.read<String>('exercise'),
          weightKg: row.readNullable<double>('weight_kg'),
          reps: row.read<int>('reps'),
          restBeforeSeconds: row.readNullable<int>('rest_before_seconds'),
          isLate: row.read<int>('is_late') != 0,
          modality: row.readNullable<String>('modality'),
        ),
    ];
  }
}
