import 'package:drift/drift.dart';

/// Read model del hub (mismo patrón que los módulos, ADR-0008): tablas
/// propias con SQL crudo sobre la database compuesta. Se reconstruyen
/// desde el log de integración, no desde el event store.

const hubWeeklyWorkoutsTable = 'hub_weekly_workouts';

/// Idempotente; la app shell lo llama en su arranque.
Future<void> createHubReadModelSchema(GeneratedDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $hubWeeklyWorkoutsTable (
      week_start    TEXT    NOT NULL PRIMARY KEY,
      workout_count INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

/// Entrenos completados en una semana ISO; [weekStart] es el lunes
/// (YYYY-MM-DD).
class WeeklyWorkoutCount {
  final String weekStart;
  final int workoutCount;

  WeeklyWorkoutCount({required this.weekStart, required this.workoutCount});
}

/// API de consulta del hub para la pantalla principal.
class HubReadModels {
  final GeneratedDatabase _db;

  HubReadModels(this._db);

  Future<List<WeeklyWorkoutCount>> weeklyWorkouts() async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM $hubWeeklyWorkoutsTable ORDER BY week_start DESC')
        .get();
    return [
      for (final row in rows)
        WeeklyWorkoutCount(
          weekStart: row.read<String>('week_start'),
          workoutCount: row.read<int>('workout_count'),
        ),
    ];
  }

  /// Entrenos de la semana de [weekStart]; 0 si no hay fila.
  Future<int> workoutsInWeek(String weekStart) async {
    final row = await _db.customSelect(
      'SELECT workout_count FROM $hubWeeklyWorkoutsTable WHERE week_start = ?',
      variables: [Variable<String>(weekStart)],
    ).getSingleOrNull();
    return row?.read<int>('workout_count') ?? 0;
  }
}
