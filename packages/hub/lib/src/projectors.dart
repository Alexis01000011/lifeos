import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'integration_events.dart';
import 'read_model.dart';

/// Una fila por workout anunciado (ADR-0010): el conteo semanal es GROUP BY
/// en la consulta, y el compensatorio `gym.workout_discarded` es un DELETE.
/// Renombrado de 'hub.weekly_workouts' a propósito: nace con checkpoint 0
/// y el catch-up del arranque lo backfillea desde el log de integración.
///
/// El tiempo que bucketiza es `completed_at` del PAYLOAD (el contrato),
/// no el occurredAt del envelope: el hub decide con la API pública.
class HubWorkoutsProjector implements IntegrationProjector {
  final GeneratedDatabase _db;

  HubWorkoutsProjector(this._db);

  @override
  String get name => 'hub.workouts';

  @override
  Set<String> get handledEventTypes =>
      {GymWorkoutCompleted.type, GymWorkoutDiscarded.type};

  @override
  FutureOr<void> project(IntegrationEventEnvelope envelope) async {
    switch (envelope.event) {
      case GymWorkoutCompleted(:final workoutId, :final completedAt):
        await _db.customStatement(
          'INSERT INTO $hubWorkoutsTable (workout_id, week_start) '
          'VALUES (?, ?)',
          [workoutId, isoWeekStartUtc(completedAt)],
        );
      case GymWorkoutDiscarded(:final workoutId):
        await _db.customStatement(
          'DELETE FROM $hubWorkoutsTable WHERE workout_id = ?',
          [workoutId],
        );
    }
    _db.notifyUpdates({const TableUpdate(hubWorkoutsTable)});
  }

  @override
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM $hubWorkoutsTable');
    _db.notifyUpdates({const TableUpdate(hubWorkoutsTable)});
  }
}
