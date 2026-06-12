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

  /// Nombre del ejercicio, denormalizado: snapshot de cómo se llamaba al
  /// registrar (ADR-0011). El evento queda autocontenido; un rename
  /// posterior no reescribe series pasadas.
  final String exercise;

  /// Identidad en el catálogo (ADR-0011). Opcional por weak schema: las
  /// series persistidas antes del catálogo quedan null y se resuelven por
  /// el mapa de nombres históricos.
  final String? exerciseId;
  final double weightKg;
  final int reps;

  /// Segundos descansados ANTES de esta serie; null si no se midió
  /// (primera serie del ejercicio, o el usuario no cronometró).
  final int? restBeforeSeconds;

  SetLogged({
    required this.exercise,
    this.exerciseId,
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
        if (exerciseId != null) 'exerciseId': exerciseId,
        'weightKg': weightKg,
        'reps': reps,
        if (restBeforeSeconds != null) 'restBeforeSeconds': restBeforeSeconds,
      };

  static SetLogged fromJson(Map<String, dynamic> json) => SetLogged(
        exercise: json['exercise'] as String,
        exerciseId: json['exerciseId'] as String?,
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

/// Eliminación de la última serie de un workout en curso (swipe en la UI).
/// Solo válido antes de completar. Lleva el payload de la serie eliminada
/// para que los projectors puedan restar el volumen sin releer la tabla.
class SetRemoved implements DomainEvent {
  static const type = 'gym.set_removed';

  final int position;
  final double weightKg;
  final int reps;

  SetRemoved({
    required this.position,
    required this.weightKg,
    required this.reps,
  });

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'position': position,
        'weightKg': weightKg,
        'reps': reps,
      };

  static SetRemoved fromJson(Map<String, dynamic> json) => SetRemoved(
        position: json['position'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
      );
}

/// Compensatorio (ADR-0010): una serie que se hizo pero no se registró,
/// agregada después de completar el workout. Distinto de [SetLogged] a
/// propósito: los projectors la bucketizan por la semana del WORKOUT, no
/// por la del envelope (la corrección puede llegar días después).
class SetLoggedLate implements DomainEvent {
  static const type = 'gym.set_logged_late';

  final String exercise;

  /// Misma semántica que en [SetLogged] (ADR-0011).
  final String? exerciseId;
  final double weightKg;
  final int reps;

  /// Misma semántica que en [SetLogged]; null si no se recuerda.
  final int? restBeforeSeconds;

  SetLoggedLate({
    required this.exercise,
    this.exerciseId,
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
        if (exerciseId != null) 'exerciseId': exerciseId,
        'weightKg': weightKg,
        'reps': reps,
        if (restBeforeSeconds != null) 'restBeforeSeconds': restBeforeSeconds,
      };

  static SetLoggedLate fromJson(Map<String, dynamic> json) => SetLoggedLate(
        exercise: json['exercise'] as String,
        exerciseId: json['exerciseId'] as String?,
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
        restBeforeSeconds: json['restBeforeSeconds'] as int?,
      );
}

/// Grupo muscular primario de un ejercicio (ADR-0011). Lista plana tomada
/// de la rutina real; agregar un valor es un cambio de código (aceptado:
/// app personal, el binario que escribe el valor nuevo es el que lo lee).
/// En el payload viaja [name] como string estable — nunca el índice.
enum MuscleGroup {
  pecho,
  hombro,
  triceps,
  espalda,
  biceps,
  pierna,
  abdomen;

  /// Etiqueta para UI (el name se mantiene sin acentos por estabilidad).
  String get label => switch (this) {
        MuscleGroup.triceps => 'tríceps',
        MuscleGroup.biceps => 'bíceps',
        _ => name,
      };
}

/// Alta de un ejercicio en el catálogo (ADR-0011). [legacyNames] vincula
/// nombres de texto libre persistidos antes del catálogo; el propio [name]
/// queda vinculado siempre, sin necesidad de repetirlo acá.
class ExerciseAdded implements DomainEvent {
  static const type = 'gym.exercise_added';

  final String exerciseId;
  final String name;
  final MuscleGroup muscleGroup;
  final List<String> legacyNames;

  ExerciseAdded({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.legacyNames = const [],
  });

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'muscleGroup': muscleGroup.name,
        if (legacyNames.isNotEmpty) 'legacyNames': legacyNames,
      };

  static ExerciseAdded fromJson(Map<String, dynamic> json) => ExerciseAdded(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        muscleGroup: MuscleGroup.values.byName(json['muscleGroup'] as String),
        legacyNames: [
          for (final n in json['legacyNames'] as List<dynamic>? ?? const [])
            n as String,
        ],
      );
}

/// Renombre de un ejercicio (ADR-0011). El nombre anterior sigue
/// perteneciendo al ejercicio a efectos de resolución de series viejas:
/// renombrar nunca rompe vínculos.
class ExerciseRenamed implements DomainEvent {
  static const type = 'gym.exercise_renamed';

  final String exerciseId;
  final String newName;

  ExerciseRenamed({required this.exerciseId, required this.newName});

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      {'exerciseId': exerciseId, 'newName': newName};

  static ExerciseRenamed fromJson(Map<String, dynamic> json) =>
      ExerciseRenamed(
        exerciseId: json['exerciseId'] as String,
        newName: json['newName'] as String,
      );
}

/// Corrección del grupo muscular de un ejercicio existente. El grupo
/// incorrecto queda en la historia; el projector aplica el correcto encima.
class ExerciseMuscleGroupCorrected implements DomainEvent {
  static const type = 'gym.exercise_muscle_group_corrected';

  final String exerciseId;
  final MuscleGroup newMuscleGroup;

  ExerciseMuscleGroupCorrected({
    required this.exerciseId,
    required this.newMuscleGroup,
  });

  @override
  String get eventType => type;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'newMuscleGroup': newMuscleGroup.name,
      };

  static ExerciseMuscleGroupCorrected fromJson(Map<String, dynamic> json) =>
      ExerciseMuscleGroupCorrected(
        exerciseId: json['exerciseId'] as String,
        newMuscleGroup:
            MuscleGroup.values.byName(json['newMuscleGroup'] as String),
      );
}

/// Registra los deserializadores del módulo. La app shell lo llama al
/// componer el registry global de domain events.
void registerGymEvents(EventTypeRegistry<DomainEvent> registry) {
  registry.register(WorkoutStarted.type, 1, WorkoutStarted.fromJson);
  registry.register(SetLogged.type, 1, SetLogged.fromJson);
  registry.register(SetRemoved.type, 1, SetRemoved.fromJson);
  registry.register(WorkoutCompleted.type, 1, WorkoutCompleted.fromJson);
  registry.register(WorkoutDiscarded.type, 1, WorkoutDiscarded.fromJson);
  registry.register(SetLoggedLate.type, 1, SetLoggedLate.fromJson);
  registry.register(ExerciseAdded.type, 1, ExerciseAdded.fromJson);
  registry.register(ExerciseRenamed.type, 1, ExerciseRenamed.fromJson);
  registry.register(ExerciseMuscleGroupCorrected.type, 1,
      ExerciseMuscleGroupCorrected.fromJson);
}
