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

  /// null = sin carga externa (ADR-0013).
  final double? weightKg;
  final int reps;
  final int? restBeforeSeconds;

  LogSet({
    required this.workoutId,
    required this.exercise,
    this.exerciseId,
    this.weightKg,
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

  /// null = sin carga externa (ADR-0013).
  final double? weightKg;
  final int reps;
  final int? restBeforeSeconds;

  AddMissedSet({
    required this.workoutId,
    required this.exercise,
    this.exerciseId,
    this.weightKg,
    required this.reps,
    this.restBeforeSeconds,
  });
}

class RemoveLastSet implements Command {
  final String workoutId;
  RemoveLastSet(this.workoutId);
}

class CorrectSet implements Command {
  final String workoutId;
  final int position;

  /// null = sin carga externa (ADR-0013).
  final double? weightKg;
  final int reps;

  CorrectSet({
    required this.workoutId,
    required this.position,
    this.weightKg,
    required this.reps,
  });
}

class AddExercise implements Command {
  final String exerciseId;
  final String name;
  final MuscleGroup muscleGroup;
  final ExerciseModality modality;
  final List<String> legacyNames;

  AddExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.modality = ExerciseModality.weighted,
    this.legacyNames = const [],
  });
}

class RenameExercise implements Command {
  final String exerciseId;
  final String newName;

  RenameExercise({required this.exerciseId, required this.newName});
}

class CorrectExerciseMuscleGroup implements Command {
  final String exerciseId;
  final MuscleGroup newMuscleGroup;

  CorrectExerciseMuscleGroup({
    required this.exerciseId,
    required this.newMuscleGroup,
  });
}

class CorrectExerciseModality implements Command {
  final String exerciseId;
  final ExerciseModality newModality;

  CorrectExerciseModality({
    required this.exerciseId,
    required this.newModality,
  });
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

class RemoveLastSetHandler implements CommandHandler<RemoveLastSet> {
  final AggregateRepository<Workout> _workouts;
  RemoveLastSetHandler(this._workouts);

  @override
  Future<void> handle(RemoveLastSet command) async {
    final workout = await _load(_workouts, command.workoutId);
    workout.removeLastSet();
    await _workouts.save(workout);
  }
}

class CorrectSetHandler implements CommandHandler<CorrectSet> {
  final AggregateRepository<Workout> _workouts;
  CorrectSetHandler(this._workouts);

  @override
  Future<void> handle(CorrectSet command) async {
    final workout = await _load(_workouts, command.workoutId);
    workout.correctSet(
      position: command.position,
      weightKg: command.weightKg,
      reps: command.reps,
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
      modality: command.modality,
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

class CorrectExerciseMuscleGroupHandler
    implements CommandHandler<CorrectExerciseMuscleGroup> {
  final AggregateRepository<ExerciseCatalog> _catalogs;
  CorrectExerciseMuscleGroupHandler(this._catalogs);

  @override
  Future<void> handle(CorrectExerciseMuscleGroup command) async {
    final catalog = await _catalogs.load(ExerciseCatalog.singletonId);
    if (catalog == null) {
      throw DomainException('El catálogo está vacío.');
    }
    catalog.correctMuscleGroup(
      exerciseId: command.exerciseId,
      newMuscleGroup: command.newMuscleGroup,
    );
    await _catalogs.save(catalog);
  }
}

class CorrectExerciseModalityHandler
    implements CommandHandler<CorrectExerciseModality> {
  final AggregateRepository<ExerciseCatalog> _catalogs;
  CorrectExerciseModalityHandler(this._catalogs);

  @override
  Future<void> handle(CorrectExerciseModality command) async {
    final catalog = await _catalogs.load(ExerciseCatalog.singletonId);
    if (catalog == null) {
      throw DomainException('El catálogo está vacío.');
    }
    catalog.correctModality(
      exerciseId: command.exerciseId,
      newModality: command.newModality,
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
