import 'package:core/core.dart';

import 'workout.dart';

/// Comandos del módulo: intenciones que la UI despacha. Los handlers solo
/// orquestan (load → método de negocio → save); las reglas viven en el
/// agregado.

class StartWorkout implements Command {
  final String workoutId;
  StartWorkout(this.workoutId);
}

class LogSet implements Command {
  final String workoutId;
  final String exercise;
  final double weightKg;
  final int reps;
  final int? restBeforeSeconds;

  LogSet({
    required this.workoutId,
    required this.exercise,
    required this.weightKg,
    required this.reps,
    this.restBeforeSeconds,
  });
}

class CompleteWorkout implements Command {
  final String workoutId;
  CompleteWorkout(this.workoutId);
}

class StartWorkoutHandler implements CommandHandler<StartWorkout> {
  final AggregateRepository<Workout> _workouts;
  StartWorkoutHandler(this._workouts);

  @override
  Future<void> handle(StartWorkout command) async {
    final existing = await _workouts.load(command.workoutId);
    if (existing != null) {
      throw DomainException('Ese workout ya existe.');
    }
    final workout = Workout(command.workoutId)..start();
    await _workouts.save(workout);
  }
}

class LogSetHandler implements CommandHandler<LogSet> {
  final AggregateRepository<Workout> _workouts;
  LogSetHandler(this._workouts);

  @override
  Future<void> handle(LogSet command) async {
    final workout = await _load(_workouts, command.workoutId);
    workout.logSet(
      exercise: command.exercise,
      weightKg: command.weightKg,
      reps: command.reps,
      restBeforeSeconds: command.restBeforeSeconds,
    );
    await _workouts.save(workout);
  }
}

class CompleteWorkoutHandler implements CommandHandler<CompleteWorkout> {
  final AggregateRepository<Workout> _workouts;
  CompleteWorkoutHandler(this._workouts);

  @override
  Future<void> handle(CompleteWorkout command) async {
    final workout = await _load(_workouts, command.workoutId);
    workout.complete();
    await _workouts.save(workout);
  }
}

Future<Workout> _load(
    AggregateRepository<Workout> workouts, String workoutId) async {
  final workout = await workouts.load(workoutId);
  if (workout == null) {
    throw DomainException('Ese workout no existe.');
  }
  return workout;
}
