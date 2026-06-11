import 'package:core/core.dart';

import 'events.dart';

/// Agregado ÚNICO del catálogo de ejercicios (ADR-0011): un solo stream
/// con todas las altas y renombres. La razón de ser singleton es la
/// invariante de unicidad de nombres — una validación sobre el conjunto
/// solo puede ser invariante de verdad dentro del agregado que contiene
/// el conjunto completo (set-validation; validarla contra un read model
/// rompería la frontera write/read).
///
/// La unicidad cubre el nombre actual de cada ejercicio, todos los que
/// tuvo (los pre-rename quedan vinculados para resolver series viejas) y
/// los legacy explícitos, normalizados con [normalizeExerciseName].
class ExerciseCatalog extends AggregateRoot {
  static const aggregateTypeName = 'gym.exercise_catalog';

  /// Id del singleton: hay UN catálogo por vida.
  static const singletonId = 'catalog';

  ExerciseCatalog(super.id);

  @override
  String get aggregateType => aggregateTypeName;

  final Map<String, String> _currentNameById = {};
  final Map<String, String> _ownerByClaimedName = {};

  int get exerciseCount => _currentNameById.length;
  bool hasExercise(String exerciseId) =>
      _currentNameById.containsKey(exerciseId);
  String? currentNameOf(String exerciseId) => _currentNameById[exerciseId];

  /// El ejercicio dueño de un nombre (actual, histórico o legacy), si hay.
  String? exerciseIdForName(String name) =>
      _ownerByClaimedName[normalizeExerciseName(name)];

  void addExercise({
    required String exerciseId,
    required String name,
    required MuscleGroup muscleGroup,
    List<String> legacyNames = const [],
  }) {
    if (exerciseId.trim().isEmpty) {
      throw DomainException('El ejercicio necesita un id.');
    }
    if (hasExercise(exerciseId)) {
      throw DomainException('Ese ejercicio ya existe en el catálogo.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw DomainException('El ejercicio necesita un nombre.');
    }
    final cleanLegacy = [
      for (final legacy in legacyNames)
        if (legacy.trim().isNotEmpty) legacy.trim(),
    ];
    final seen = <String>{};
    for (final claimed in [cleanName, ...cleanLegacy]) {
      final normalized = normalizeExerciseName(claimed);
      if (!seen.add(normalized)) {
        throw DomainException('"$claimed" está repetido en el alta.');
      }
      final owner = _ownerByClaimedName[normalized];
      if (owner != null) {
        throw DomainException(
            '"$claimed" ya pertenece a "${_currentNameById[owner]}".');
      }
    }
    raise(ExerciseAdded(
      exerciseId: exerciseId,
      name: cleanName,
      muscleGroup: muscleGroup,
      legacyNames: cleanLegacy,
    ));
  }

  void renameExercise({required String exerciseId, required String newName}) {
    if (!hasExercise(exerciseId)) {
      throw DomainException('Ese ejercicio no existe en el catálogo.');
    }
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      throw DomainException('El ejercicio necesita un nombre.');
    }
    final owner = _ownerByClaimedName[normalizeExerciseName(cleanName)];
    if (owner != null && owner != exerciseId) {
      throw DomainException(
          '"$cleanName" ya pertenece a "${_currentNameById[owner]}".');
    }
    if (cleanName == _currentNameById[exerciseId]) return;
    raise(ExerciseRenamed(exerciseId: exerciseId, newName: cleanName));
  }

  @override
  void apply(DomainEvent event) {
    switch (event) {
      case ExerciseAdded(
          :final exerciseId,
          :final name,
          :final legacyNames
        ):
        _currentNameById[exerciseId] = name;
        for (final claimed in [name, ...legacyNames]) {
          _ownerByClaimedName[normalizeExerciseName(claimed)] = exerciseId;
        }
      case ExerciseRenamed(:final exerciseId, :final newName):
        // El nombre viejo NO se libera: sigue resolviendo series viejas.
        _currentNameById[exerciseId] = newName;
        _ownerByClaimedName[normalizeExerciseName(newName)] = exerciseId;
      default:
        throw StateError('Evento ajeno al catálogo: ${event.eventType}');
    }
  }
}

/// Normalización compartida entre el agregado (unicidad) y el read-side
/// (resolución de series viejas): trim + case-insensitive.
String normalizeExerciseName(String name) => name.trim().toLowerCase();

/// Fábrica del repositorio (la app shell la cablea en un provider).
AggregateRepository<ExerciseCatalog> exerciseCatalogRepository(
        EventStore store) =>
    AggregateRepository(
        store, ExerciseCatalog.aggregateTypeName, ExerciseCatalog.new);
