import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import 'integration_events.dart';
import 'read_model.dart';

/// Cuenta entrenos completados por semana ISO. Acumulador no idempotente
/// por sí solo: depende de la guarda de checkpoint del
/// IntegrationProjectionEngine (mismo trato que los projectors de gym).
///
/// El tiempo que bucketiza es `completed_at` del PAYLOAD (el contrato),
/// no el occurredAt del envelope: el hub decide con la API pública.
class WeeklyWorkoutCountProjector implements IntegrationProjector {
  final GeneratedDatabase _db;

  WeeklyWorkoutCountProjector(this._db);

  @override
  String get name => 'hub.weekly_workouts';

  @override
  Set<String> get handledEventTypes => {GymWorkoutCompleted.type};

  @override
  FutureOr<void> project(IntegrationEventEnvelope envelope) async {
    final completed = envelope.event as GymWorkoutCompleted;
    await _db.customStatement(
      'INSERT INTO $hubWeeklyWorkoutsTable (week_start, workout_count) '
      'VALUES (?, 1) '
      'ON CONFLICT (week_start) DO UPDATE SET workout_count = workout_count + 1',
      [isoWeekStartUtc(completed.completedAt)],
    );
    _db.notifyUpdates({const TableUpdate(hubWeeklyWorkoutsTable)});
  }

  @override
  Future<void> reset() async {
    await _db.customStatement('DELETE FROM $hubWeeklyWorkoutsTable');
    _db.notifyUpdates({const TableUpdate(hubWeeklyWorkoutsTable)});
  }
}
