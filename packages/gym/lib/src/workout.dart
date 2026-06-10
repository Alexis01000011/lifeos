import 'package:core/core.dart';

import 'events.dart';

/// Agregado raíz: UN entrenamiento (no el historial — agregados chicos,
/// ADR-0001). Frontera de consistencia del ciclo de vida:
/// started → series → completed.
///
/// Las invariantes se validan en los métodos de negocio; apply() solo
/// muta estado (puro: los eventos persistidos ya pasaron validación).
class Workout extends AggregateRoot {
  static const aggregateTypeName = 'gym.workout';

  Workout(super.id);

  @override
  String get aggregateType => aggregateTypeName;

  bool _started = false;
  bool _completed = false;
  int _setCount = 0;

  bool get isCompleted => _completed;
  int get setCount => _setCount;

  void start() {
    if (_started) {
      throw DomainException('Este workout ya fue iniciado.');
    }
    raise(WorkoutStarted());
  }

  void logSet({
    required String exercise,
    required double weightKg,
    required int reps,
    int? restBeforeSeconds,
  }) {
    _ensureStarted();
    if (_completed) {
      throw DomainException(
          'Este workout ya está completado; no se pueden agregar series.');
    }
    if (exercise.trim().isEmpty) {
      throw DomainException('La serie necesita un ejercicio.');
    }
    if (reps < 1) {
      throw DomainException('Una serie tiene al menos 1 repetición.');
    }
    if (weightKg < 0) {
      throw DomainException('El peso no puede ser negativo.');
    }
    if (restBeforeSeconds != null && restBeforeSeconds < 0) {
      throw DomainException('El descanso no puede ser negativo.');
    }
    raise(SetLogged(
      exercise: exercise.trim(),
      weightKg: weightKg,
      reps: reps,
      restBeforeSeconds: restBeforeSeconds,
    ));
  }

  void complete() {
    _ensureStarted();
    if (_completed) {
      throw DomainException('Este workout ya fue completado.');
    }
    if (_setCount == 0) {
      throw DomainException(
          'No se puede completar un workout sin series registradas.');
    }
    raise(WorkoutCompleted());
  }

  void _ensureStarted() {
    if (!_started) {
      throw DomainException('Este workout no fue iniciado.');
    }
  }

  @override
  void apply(DomainEvent event) {
    switch (event) {
      case WorkoutStarted():
        _started = true;
      case SetLogged():
        _setCount++;
      case WorkoutCompleted():
        _completed = true;
      default:
        throw StateError('Evento ajeno al Workout: ${event.eventType}');
    }
  }
}

/// Fábrica del repositorio del módulo (la app shell la cablea en un
/// provider Riverpod sobre el EventStore real).
AggregateRepository<Workout> workoutRepository(EventStore store) =>
    AggregateRepository(store, Workout.aggregateTypeName, Workout.new);
