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
  bool _discarded = false;
  int _setCount = 0;

  bool get isCompleted => _completed;
  bool get isDiscarded => _discarded;
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
    _ensureNotDiscarded();
    if (_completed) {
      throw DomainException(
          'Este workout ya está completado; no se pueden agregar series.');
    }
    _validateSet(exercise, weightKg, reps, restBeforeSeconds);
    raise(SetLogged(
      exercise: exercise.trim(),
      weightKg: weightKg,
      reps: reps,
      restBeforeSeconds: restBeforeSeconds,
    ));
  }

  void complete() {
    _ensureStarted();
    _ensureNotDiscarded();
    if (_completed) {
      throw DomainException('Este workout ya fue completado.');
    }
    if (_setCount == 0) {
      throw DomainException(
          'No se puede completar un workout sin series registradas.');
    }
    raise(WorkoutCompleted());
  }

  /// Compensatorio (ADR-0010): este workout no cuenta. Vale tanto en curso
  /// (tap por error) como completado (fantasma que ya se anunció); el
  /// evento registra cuál de los dos era para que la policy de integración
  /// sepa si hay algo que compensar hacia afuera.
  void discard() {
    _ensureStarted();
    _ensureNotDiscarded();
    raise(WorkoutDiscarded(wasCompleted: _completed));
  }

  /// Compensatorio (ADR-0010): serie hecha pero no registrada, agregada a
  /// un workout YA completado. Sobre uno en curso se usa [logSet]: acá la
  /// restricción a completados es lo que mantiene honesta la invariante
  /// "no series tras completar" del camino normal.
  void addMissedSet({
    required String exercise,
    required double weightKg,
    required int reps,
    int? restBeforeSeconds,
  }) {
    _ensureStarted();
    _ensureNotDiscarded();
    if (!_completed) {
      throw DomainException(
          'El workout sigue en curso: registrá la serie normalmente.');
    }
    _validateSet(exercise, weightKg, reps, restBeforeSeconds);
    raise(SetLoggedLate(
      exercise: exercise.trim(),
      weightKg: weightKg,
      reps: reps,
      restBeforeSeconds: restBeforeSeconds,
    ));
  }

  void _validateSet(
      String exercise, double weightKg, int reps, int? restBeforeSeconds) {
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
  }

  void _ensureStarted() {
    if (!_started) {
      throw DomainException('Este workout no fue iniciado.');
    }
  }

  void _ensureNotDiscarded() {
    if (_discarded) {
      throw DomainException('Este workout fue descartado.');
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
      case WorkoutDiscarded():
        _discarded = true;
      case SetLoggedLate():
        _setCount++;
      default:
        throw StateError('Evento ajeno al Workout: ${event.eventType}');
    }
  }
}

/// Fábrica del repositorio del módulo (la app shell la cablea en un
/// provider Riverpod sobre el EventStore real).
AggregateRepository<Workout> workoutRepository(EventStore store) =>
    AggregateRepository(store, Workout.aggregateTypeName, Workout.new);
