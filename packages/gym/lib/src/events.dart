import 'package:core/core.dart';

/// Domain events del workout (ADR-0007: ciclo de vida, no evento gordo).
/// Privados del módulo: pueden evolucionar con libertad mientras el
/// registry sepa leer lo ya persistido (weak schema + upcasters).

class WorkoutStarted implements DomainEvent {
  static const type = 'gym.workout_started';

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => const {};

  static WorkoutStarted fromJson(Map<String, dynamic> json) =>
      WorkoutStarted();
}

class SetLogged implements DomainEvent {
  static const type = 'gym.set_logged';

  /// Nombre libre del ejercicio (el catálogo propio llega en Hito 2).
  final String exercise;
  final double weightKg;
  final int reps;

  /// Segundos descansados ANTES de esta serie; null si no se midió
  /// (primera serie del ejercicio, o el usuario no cronometró).
  final int? restBeforeSeconds;

  SetLogged({
    required this.exercise,
    required this.weightKg,
    required this.reps,
    this.restBeforeSeconds,
  });

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'exercise': exercise,
        'weightKg': weightKg,
        'reps': reps,
        if (restBeforeSeconds != null) 'restBeforeSeconds': restBeforeSeconds,
      };

  static SetLogged fromJson(Map<String, dynamic> json) => SetLogged(
        exercise: json['exercise'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
        restBeforeSeconds: json['restBeforeSeconds'] as int?,
      );
}

class WorkoutCompleted implements DomainEvent {
  static const type = 'gym.workout_completed';

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => const {};

  static WorkoutCompleted fromJson(Map<String, dynamic> json) =>
      WorkoutCompleted();
}

/// Registra los deserializadores del módulo. La app shell lo llama al
/// componer el registry global de domain events.
void registerGymEvents(EventTypeRegistry<DomainEvent> registry) {
  registry.register(WorkoutStarted.type, 1, WorkoutStarted.fromJson);
  registry.register(SetLogged.type, 1, SetLogged.fromJson);
  registry.register(WorkoutCompleted.type, 1, WorkoutCompleted.fromJson);
}
