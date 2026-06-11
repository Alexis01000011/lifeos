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

/// Compensatorio (ADR-0010): el workout no cuenta — fue un tap por error o
/// un fantasma. Terminal: nada se le puede hacer a un workout descartado.
/// El log conserva todo; son las proyecciones las que lo olvidan.
class WorkoutDiscarded implements DomainEvent {
  static const type = 'gym.workout_discarded';

  /// true si el workout estaba completado al descartarse: la policy de
  /// integración solo compensa hacia afuera lo que ya se anunció.
  final bool wasCompleted;

  WorkoutDiscarded({required this.wasCompleted});

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {'wasCompleted': wasCompleted};

  static WorkoutDiscarded fromJson(Map<String, dynamic> json) =>
      WorkoutDiscarded(wasCompleted: json['wasCompleted'] as bool? ?? false);
}

/// Compensatorio (ADR-0010): una serie que se hizo pero no se registró,
/// agregada después de completar el workout. Distinto de [SetLogged] a
/// propósito: los projectors la bucketizan por la semana del WORKOUT, no
/// por la del envelope (la corrección puede llegar días después).
class SetLoggedLate implements DomainEvent {
  static const type = 'gym.set_logged_late';

  final String exercise;
  final double weightKg;
  final int reps;

  /// Misma semántica que en [SetLogged]; null si no se recuerda.
  final int? restBeforeSeconds;

  SetLoggedLate({
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

  static SetLoggedLate fromJson(Map<String, dynamic> json) => SetLoggedLate(
        exercise: json['exercise'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
        restBeforeSeconds: json['restBeforeSeconds'] as int?,
      );
}

/// Registra los deserializadores del módulo. La app shell lo llama al
/// componer el registry global de domain events.
void registerGymEvents(EventTypeRegistry<DomainEvent> registry) {
  registry.register(WorkoutStarted.type, 1, WorkoutStarted.fromJson);
  registry.register(SetLogged.type, 1, SetLogged.fromJson);
  registry.register(WorkoutCompleted.type, 1, WorkoutCompleted.fromJson);
  registry.register(WorkoutDiscarded.type, 1, WorkoutDiscarded.fromJson);
  registry.register(SetLoggedLate.type, 1, SetLoggedLate.fromJson);
}
