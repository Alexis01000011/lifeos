import 'package:drift/drift.dart';

/// Read model del módulo (ADR-0008): tablas propias creadas con SQL crudo
/// sobre la database compuesta. Nadie fuera de gym lee estas tablas.

const workoutHistoryTable = 'gym_workout_history';
const weeklyVolumeTable = 'gym_weekly_volume';

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
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $weeklyVolumeTable (
      week_start      TEXT NOT NULL PRIMARY KEY,
      total_volume_kg REAL NOT NULL DEFAULT 0
    )
  ''');
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
            'SELECT * FROM $weeklyVolumeTable ORDER BY week_start DESC')
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
