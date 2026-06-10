import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'events.dart';
import 'read_model.dart';

/// Lunes (ISO) de la semana de [moment], como YYYY-MM-DD.
///
/// Bucketiza en UTC: simplificación aceptada del esqueleto (un entreno
/// nocturno puede caer en el día UTC siguiente). Se revisará en Hito 2
/// junto con el tiempo de negocio (ADR-0003).
String isoWeekStartUtc(DateTime moment) {
  final utc = moment.toUtc();
  final date = DateTime.utc(utc.year, utc.month, utc.day);
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(monday.year, 4)}-${pad(monday.month, 2)}-${pad(monday.day, 2)}';
}

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
