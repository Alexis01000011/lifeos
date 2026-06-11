import 'package:drift/drift.dart';

/// Read model del hub (mismo patrón que los módulos, ADR-0008): tablas
/// propias con SQL crudo sobre la database compuesta. Se reconstruyen
/// desde el log de integración, no desde el event store.

const hubWorkoutsTable = 'hub_workouts';

/// Idempotente; la app shell lo llama en su arranque.
Future<void> createHubReadModelSchema(GeneratedDatabase db) async {
  // Granular (ADR-0010): una fila por workout anunciado; el conteo semanal
  // es GROUP BY en la consulta. Un workout_discarded compensatorio es un
  // DELETE — el acumulador viejo no sabía restar.
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS $hubWorkoutsTable (
      workout_id TEXT NOT NULL PRIMARY KEY,
      week_start TEXT NOT NULL
    )
  ''');
  await db.customStatement('DROP TABLE IF EXISTS hub_weekly_workouts');
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
            'SELECT week_start, COUNT(*) AS workout_count '
            'FROM $hubWorkoutsTable GROUP BY week_start '
            'ORDER BY week_start DESC')
        .get();
    return [
      for (final row in rows)
        WeeklyWorkoutCount(
          weekStart: row.read<String>('week_start'),
          workoutCount: row.read<int>('workout_count'),
        ),
    ];
  }

  /// Entrenos de la semana de [weekStart]; 0 si no hay ninguno.
  Future<int> workoutsInWeek(String weekStart) async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS workout_count FROM $hubWorkoutsTable '
      'WHERE week_start = ?',
      variables: [Variable<String>(weekStart)],
    ).getSingle();
    return row.read<int>('workout_count');
  }
}
