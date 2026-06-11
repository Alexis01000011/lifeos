import 'package:drift/drift.dart';

/// Read model del módulo (ADR-0008): tablas propias creadas con SQL crudo
/// sobre la database compuesta. Nadie fuera de gym lee estas tablas.

const workoutHistoryTable = 'gym_workout_history';
const gymSetsTable = 'gym_sets';

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
  // Granular (ADR-0010): una fila por serie; el volumen semanal es un
  // GROUP BY en la consulta. Así el descarte es un DELETE y no hay
  // acumulador que no sepa restar. Es además la base del detalle de
  // entreno y las estadísticas de progresión del Hito 2.
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $gymSetsTable (
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

  Future<List<WeeklyVolume>> weeklyVolume() async {
    final rows = await _db
        .customSelect(
            'SELECT week_start, SUM(weight_kg * reps) AS total_volume_kg '
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
}
