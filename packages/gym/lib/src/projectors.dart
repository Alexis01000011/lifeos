import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'events.dart';
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
  Set<String> get handledEventTypes =>
      {WorkoutStarted.type, SetLogged.type, WorkoutCompleted.type};

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
      case SetLogged(:final weightKg, :final reps):
        await _db.customStatement(
          'UPDATE $workoutHistoryTable '
          'SET set_count = set_count + 1, '
          '    total_volume_kg = total_volume_kg + ? '
          'WHERE workout_id = ?',
          [weightKg * reps, workoutId],
        );
      case WorkoutCompleted():
        await _db.customStatement(
          'UPDATE $workoutHistoryTable SET completed_at = ? '
          'WHERE workout_id = ?',
          [envelope.occurredAt.microsecondsSinceEpoch, workoutId],
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

/// La estadística derivada del esqueleto: volumen (kg×reps) acumulado por
/// semana ISO. Mismo contrato de idempotencia que el historial.
class WeeklyVolumeProjector implements Projector {
  final GeneratedDatabase _db;

  WeeklyVolumeProjector(this._db);

  @override
  String get name => 'gym.weekly_volume';

  @override
  Set<String> get handledEventTypes => {SetLogged.type};

  @override
  FutureOr<void> project(EventEnvelope envelope) async {
    final set = envelope.event as SetLogged;
    await _db.customStatement(
      'INSERT INTO $weeklyVolumeTable (week_start, total_volume_kg) '
      'VALUES (?, ?) '
      'ON CONFLICT (week_start) '
      'DO UPDATE SET total_volume_kg = total_volume_kg + excluded.total_volume_kg',
      [isoWeekStartUtc(envelope.occurredAt), set.weightKg * set.reps],
    );
    _db.notifyUpdates({TableUpdate(weeklyVolumeTable)});
  }

  @override
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM $weeklyVolumeTable');
    _db.notifyUpdates({TableUpdate(weeklyVolumeTable)});
  }
}
