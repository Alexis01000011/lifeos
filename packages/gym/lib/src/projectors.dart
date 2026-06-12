import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'events.dart';
import 'exercise_catalog.dart';
import 'read_model.dart';

// isoWeekStartUtc se movió a core en Fase 4 (el hub también bucketiza por
// semana y no puede importar gym); se re-exporta para no romper a nadie.
export 'package:core/core.dart' show isoWeekStartUtc;

/// Proyección de historial: una fila por workout, actualizada en vivo.
/// No es idempotente por sí sola (los acumuladores += dependen de la
/// guarda de checkpoint del ProjectionEngine, que es quien garantiza
/// "cada envelope a lo sumo una vez").
class WorkoutHistoryProjector implements Projector {
  final GeneratedDatabase _db;

  WorkoutHistoryProjector(this._db);

  @override
  String get name => 'gym.workout_history';

  @override
  Set<String> get handledEventTypes => {
        WorkoutStarted.type,
        SetLogged.type,
        SetRemoved.type,
        SetCorrected.type,
        WorkoutCompleted.type,
        WorkoutDiscarded.type,
        SetLoggedLate.type,
      };

  @override
  FutureOr<void> project(EventEnvelope envelope) async {
    final workoutId = envelope.streamId.aggregateId;
    switch (envelope.event) {
      case WorkoutStarted():
        await _db.customStatement(
          'INSERT INTO $workoutHistoryTable (workout_id, started_at) '
          'VALUES (?, ?)',
          [workoutId, envelope.occurredAt.microsecondsSinceEpoch],
        );
      // Peso null = sin carga externa (ADR-0013): aporta 0 al volumen,
      // que desde ese ADR significa "carga externa total".
      case SetLogged(:final weightKg, :final reps):
      case SetLoggedLate(:final weightKg, :final reps):
        await _db.customStatement(
          'UPDATE $workoutHistoryTable '
          'SET set_count = set_count + 1, '
          '    total_volume_kg = total_volume_kg + ? '
          'WHERE workout_id = ?',
          [(weightKg ?? 0) * reps, workoutId],
        );
      case SetRemoved(:final weightKg, :final reps):
        await _db.customStatement(
          'UPDATE $workoutHistoryTable '
          'SET set_count = set_count - 1, '
          '    total_volume_kg = total_volume_kg - ? '
          'WHERE workout_id = ?',
          [(weightKg ?? 0) * reps, workoutId],
        );
      case SetCorrected(:final oldWeightKg, :final oldReps, :final weightKg, :final reps):
        final delta = (weightKg ?? 0) * reps - (oldWeightKg ?? 0) * oldReps;
        await _db.customStatement(
          'UPDATE $workoutHistoryTable '
          'SET total_volume_kg = total_volume_kg + ? '
          'WHERE workout_id = ?',
          [delta, workoutId],
        );
      case WorkoutCompleted():
        await _db.customStatement(
          'UPDATE $workoutHistoryTable SET completed_at = ? '
          'WHERE workout_id = ?',
          [envelope.occurredAt.microsecondsSinceEpoch, workoutId],
        );
      case WorkoutDiscarded():
        // El read model lo olvida; el event store lo recuerda (ADR-0010).
        await _db.customStatement(
          'DELETE FROM $workoutHistoryTable WHERE workout_id = ?',
          [workoutId],
        );
    }
    _db.notifyUpdates({TableUpdate(workoutHistoryTable)});
  }

  @override
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM $workoutHistoryTable');
    _db.notifyUpdates({TableUpdate(workoutHistoryTable)});
  }
}

/// Una fila por serie (ADR-0010): reemplaza al acumulador semanal — el
/// volumen por semana ahora es GROUP BY en la consulta. El nombre es nuevo
/// a propósito: nace con checkpoint 0 y el catch-up del arranque lo
/// backfillea con los eventos ya persistidos.
class WorkoutSetsProjector implements Projector {
  final GeneratedDatabase _db;

  WorkoutSetsProjector(this._db);

  @override
  // Renacido como _v2 (ADR-0013): weight_kg pasó a nullable y la tabla se
  // recrea; el nombre nuevo arranca en checkpoint 0 y el catch-up del
  // arranque la backfillea (mecánica de ADR-0010).
  String get name => 'gym.workout_sets_v2';

  @override
  Set<String> get handledEventTypes => {
        SetLogged.type,
        SetRemoved.type,
        SetCorrected.type,
        SetLoggedLate.type,
        WorkoutDiscarded.type,
      };

  @override
  FutureOr<void> project(EventEnvelope envelope) async {
    final workoutId = envelope.streamId.aggregateId;
    switch (envelope.event) {
      case SetLogged(:final exercise, :final weightKg, :final reps, :final restBeforeSeconds):
        await _db.customStatement(
          'INSERT INTO $gymSetsTable (workout_id, position, exercise, '
          'weight_kg, reps, rest_before_seconds, week_start, is_late) '
          'VALUES (?, (SELECT COUNT(*) + 1 FROM $gymSetsTable WHERE workout_id = ?), '
          '?, ?, ?, ?, ?, 0)',
          [
            workoutId,
            workoutId,
            exercise,
            weightKg,
            reps,
            restBeforeSeconds,
            isoWeekStartUtc(envelope.occurredAt),
          ],
        );
      case SetRemoved(:final position):
        await _db.customStatement(
          'DELETE FROM $gymSetsTable WHERE workout_id = ? AND position = ?',
          [workoutId, position],
        );
      case SetCorrected(:final position, :final weightKg, :final reps):
        await _db.customStatement(
          'UPDATE $gymSetsTable SET weight_kg = ?, reps = ? '
          'WHERE workout_id = ? AND position = ?',
          [weightKg, reps, workoutId, position],
        );
      case SetLoggedLate(:final exercise, :final weightKg, :final reps, :final restBeforeSeconds):
        // La semana es la del WORKOUT, no la de la corrección: se hereda de
        // la primera serie, que siempre existe (no se completa sin series,
        // y la serie tardía solo vale sobre completados). Si la invariante
        // se rompiera, el NOT NULL de week_start aborta la transacción.
        await _db.customStatement(
          'INSERT INTO $gymSetsTable (workout_id, position, exercise, '
          'weight_kg, reps, rest_before_seconds, week_start, is_late) '
          'VALUES (?, (SELECT COUNT(*) + 1 FROM $gymSetsTable WHERE workout_id = ?), '
          '?, ?, ?, ?, '
          '(SELECT week_start FROM $gymSetsTable WHERE workout_id = ? '
          ' ORDER BY position LIMIT 1), 1)',
          [workoutId, workoutId, exercise, weightKg, reps, restBeforeSeconds, workoutId],
        );
      case WorkoutDiscarded():
        await _db.customStatement(
          'DELETE FROM $gymSetsTable WHERE workout_id = ?',
          [workoutId],
        );
    }
    _db.notifyUpdates({TableUpdate(gymSetsTable)});
  }

  @override
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM $gymSetsTable');
    _db.notifyUpdates({TableUpdate(gymSetsTable)});
  }
}

/// Catálogo de ejercicios (ADR-0011): una fila por ejercicio más el mapa
/// de nombres con que las consultas resuelven series viejas a texto libre.
/// Nombre nuevo → checkpoint 0 → el catch-up del arranque lo puebla.
class ExerciseCatalogProjector implements Projector {
  final GeneratedDatabase _db;

  ExerciseCatalogProjector(this._db);

  @override
  String get name => 'gym.exercises';

  @override
  Set<String> get handledEventTypes => {
        ExerciseAdded.type,
        ExerciseRenamed.type,
        ExerciseMuscleGroupCorrected.type,
        ExerciseModalityCorrected.type,
      };

  @override
  FutureOr<void> project(EventEnvelope envelope) async {
    switch (envelope.event) {
      case ExerciseAdded(
          :final exerciseId,
          :final name,
          :final muscleGroup,
          :final modality,
          :final legacyNames
        ):
        await _db.customStatement(
          'INSERT INTO $gymExercisesTable '
          '(exercise_id, name, muscle_group, modality) '
          'VALUES (?, ?, ?, ?)',
          [exerciseId, name, muscleGroup.name, modality.name],
        );
        for (final claimed in [name, ...legacyNames]) {
          await _db.customStatement(
            'INSERT INTO $gymExerciseNamesTable (name_normalized, exercise_id) '
            'VALUES (?, ?)',
            [normalizeExerciseName(claimed), exerciseId],
          );
        }
      case ExerciseRenamed(:final exerciseId, :final newName):
        await _db.customStatement(
          'UPDATE $gymExercisesTable SET name = ? WHERE exercise_id = ?',
          [newName, exerciseId],
        );
        // OR IGNORE: un rename que solo cambia mayúsculas re-reclama un
        // nombre que el ejercicio ya tenía vinculado.
        await _db.customStatement(
          'INSERT OR IGNORE INTO $gymExerciseNamesTable '
          '(name_normalized, exercise_id) VALUES (?, ?)',
          [normalizeExerciseName(newName), exerciseId],
        );
      case ExerciseMuscleGroupCorrected(:final exerciseId, :final newMuscleGroup):
        await _db.customStatement(
          'UPDATE $gymExercisesTable SET muscle_group = ? WHERE exercise_id = ?',
          [newMuscleGroup.name, exerciseId],
        );
      case ExerciseModalityCorrected(:final exerciseId, :final newModality):
        await _db.customStatement(
          'UPDATE $gymExercisesTable SET modality = ? WHERE exercise_id = ?',
          [newModality.name, exerciseId],
        );
    }
    _db.notifyUpdates(
        {TableUpdate(gymExercisesTable), TableUpdate(gymExerciseNamesTable)});
  }

  @override
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM $gymExercisesTable');
    await _db.customStatement('DELETE FROM $gymExerciseNamesTable');
    _db.notifyUpdates(
        {TableUpdate(gymExercisesTable), TableUpdate(gymExerciseNamesTable)});
  }
}
