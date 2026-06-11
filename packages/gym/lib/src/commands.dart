import 'package:core/core.dart';

import 'events.dart';
import 'exercise_catalog.dart';
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
  final String? exerciseId;
  final double weightKg;
  final int reps;
  final int? restBeforeSeconds;

  LogSet({
    required this.workoutId,
    required this.exercise,
    this.exerciseId,
    required this.weightKg,
    required this.reps,
    this.restBeforeSeconds,
  });
}

class CompleteWorkout implements Command {
  final String workoutId;
  CompleteWorkout(this.workoutId);
}

class DiscardWorkout implements Command {
  final String workoutId;
  DiscardWorkout(this.workoutId);
}

class AddMissedSet implements Command {
  final String workoutId;
  final String exercise;
  final String? exerciseId;
  final double weightKg;
  final int reps;
  final int? restBeforeSeconds;

  AddMissedSet({
    required this.workoutId,
    required this.exercise,
    this.exerciseId,
    required this.weightKg,
    required this.reps,
    this.restBeforeSeconds,
  });
}

class AddExercise implements Command {
  final String exerciseId;
  final String name;
  final MuscleGroup muscleGroup;
  final List<String> legacyNames;

  AddExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.legacyNames = const [],
  });
}

class RenameExercise implements Command {
  final String exerciseId;
  final String newName;

  RenameExercise({required this.exerciseId, required this.newName});
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
      exerciseId: command.exerciseId,
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

class DiscardWorkoutHandler implements CommandHandler<DiscardWorkout> {
  final AggregateRepository<Workout> _workouts;
  DiscardWorkoutHandler(this._workouts);

  @override
  Future<void> handle(DiscardWorkout command) async {
    final workout = await _load(_workouts, command.workoutId);
    workout.discard();
    await _workouts.save(workout);
  }
}

class AddMissedSetHandler implements CommandHandler<AddMissedSet> {
  final AggregateRepository<Workout> _workouts;
  AddMissedSetHandler(this._workouts);

  @override
  Future<void> handle(AddMissedSet command) async {
    final workout = await _load(_workouts, command.workoutId);
    workout.addMissedSet(
      exercise: command.exercise,
      exerciseId: command.exerciseId,
      weightKg: command.weightKg,
      reps: command.reps,
      restBeforeSeconds: command.restBeforeSeconds,
    );
    await _workouts.save(workout);
  }
}

/// El primer alta crea el agregado singleton (load-or-create): el catálogo
/// no tiene un "comando de creación" propio — existe desde que tiene algo.
class AddExerciseHandler implements CommandHandler<AddExercise> {
  final AggregateRepository<ExerciseCatalog> _catalogs;
  AddExerciseHandler(this._catalogs);

  @override
  Future<void> handle(AddExercise command) async {
    final catalog = await _catalogs.load(ExerciseCatalog.singletonId) ??
        ExerciseCatalog(ExerciseCatalog.singletonId);
    catalog.addExercise(
      exerciseId: command.exerciseId,
      name: command.name,
      muscleGroup: command.muscleGroup,
      legacyNames: command.legacyNames,
    );
    await _catalogs.save(catalog);
  }
}

class RenameExerciseHandler implements CommandHandler<RenameExercise> {
  final AggregateRepository<ExerciseCatalog> _catalogs;
  RenameExerciseHandler(this._catalogs);

  @override
  Future<void> handle(RenameExercise command) async {
    final catalog = await _catalogs.load(ExerciseCatalog.singletonId);
    if (catalog == null) {
      throw DomainException('El catálogo está vacío.');
    }
    catalog.renameExercise(
      exerciseId: command.exerciseId,
      newName: command.newName,
    );
    await _catalogs.save(catalog);
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
