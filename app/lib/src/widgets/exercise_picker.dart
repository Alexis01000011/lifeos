import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';
import 'package:uuid/uuid.dart';

import '../providers.dart';

/// Selección de ejercicio del catálogo (ADR-0011): el texto libre murió
/// como entrada. Campo que muestra el elegido y abre el picker, con alta
/// al vuelo para no cortar el flujo en pleno entreno.
class ExercisePickerField extends ConsumerWidget {
  final ExerciseSummary? selected;
  final ValueChanged<ExerciseSummary> onSelected;

  const ExercisePickerField({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final elegido = await showExercisePicker(context);
        if (elegido != null) onSelected(elegido);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Ejercicio',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        isEmpty: selected == null,
        child: selected == null ? null : Text(selected!.name),
      ),
    );
  }
}

/// Abre el picker como bottom sheet; devuelve el ejercicio elegido o
/// creado, o null si se canceló.
Future<ExerciseSummary?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<ExerciseSummary>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ExercisePickerSheet(),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet();

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  var _query = '';
  var _frecuentesExpanded = true;

  /// Devuelve el grupo muscular si el query coincide exactamente con su
  /// nombre o etiqueta (case-insensitive). Si no hay match, devuelve null
  /// y el filtro opera sobre el nombre del ejercicio.
  MuscleGroup? _matchMuscleGroup(String query) {
    if (query.isEmpty) return null;
    final q = normalizeExerciseName(query);
    for (final g in MuscleGroup.values) {
      if (normalizeExerciseName(g.name) == q ||
          normalizeExerciseName(g.label) == q) {
        return g;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final exercises =
        ref.watch(exercisesProvider).value ?? const <ExerciseSummary>[];
    final frequent =
        ref.watch(exercisesByFrequencyProvider).value ?? const <ExerciseSummary>[];

    final showFrecuentes = _query.isEmpty && frequent.isNotEmpty;
    final frequentIds =
        showFrecuentes ? {for (final e in frequent) e.exerciseId} : const <String>{};

    final List<ExerciseSummary> filtered;
    if (_query.isEmpty) {
      // Sin búsqueda: muestra todos excepto los ya en "Frecuentes".
      filtered = [
        for (final e in exercises)
          if (!frequentIds.contains(e.exerciseId)) e,
      ];
    } else {
      // Con búsqueda: filtra por grupo si coincide, si no por nombre.
      final matchedGroup = _matchMuscleGroup(_query);
      filtered = [
        for (final e in exercises)
          if (matchedGroup != null
              ? e.muscleGroup == matchedGroup.name
              : normalizeExerciseName(e.name)
                  .contains(normalizeExerciseName(_query)))
            e,
      ];
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('buscar-ejercicio'),
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Buscar ejercicio',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            ListTile(
              key: const Key('nuevo-ejercicio'),
              leading: const Icon(Icons.add),
              title: Text(_query.trim().isEmpty
                  ? 'Nuevo ejercicio…'
                  : 'Crear "${_query.trim()}"…'),
              onTap: () async {
                final creado = await showAddExerciseDialog(context, ref,
                    initialName: _query.trim());
                if (creado != null && context.mounted) {
                  Navigator.pop(context, creado);
                }
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: exercises.isEmpty
                  ? const Center(
                      child: Text('El catálogo está vacío: crea el primero.'))
                  : ListView(
                      children: [
                        if (showFrecuentes) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 8, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Frecuentes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _frecuentesExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(() =>
                                      _frecuentesExpanded =
                                          !_frecuentesExpanded),
                                ),
                              ],
                            ),
                          ),
                          // Fondo primary-container (token de "chip
                          // activo"): los frecuentes se distinguen de un
                          // vistazo del resto del catálogo.
                          if (_frecuentesExpanded)
                            for (final exercise in frequent)
                              ListTile(
                                tileColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                title: Text(exercise.name),
                                subtitle: Text(
                                    muscleGroupLabel(exercise.muscleGroup)),
                                onTap: () =>
                                    Navigator.pop(context, exercise),
                              ),
                          // Header espejo de "Frecuentes": marca dónde
                          // empieza el catálogo completo.
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Todos',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                        for (final exercise in filtered)
                          ListTile(
                            title: Text(exercise.name),
                            subtitle: Text(
                                muscleGroupLabel(exercise.muscleGroup)),
                            onTap: () => Navigator.pop(context, exercise),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta de ejercicio (la usan el picker y la pantalla Ejercicios).
/// Devuelve el creado, o null si se canceló o el dominio lo rechazó.
Future<ExerciseSummary?> showAddExerciseDialog(
    BuildContext context, WidgetRef ref,
    {String initialName = ''}) async {
  final nombre = TextEditingController(text: initialName);
  final historicos = TextEditingController();
  MuscleGroup? grupo;
  var modalidad = ExerciseModality.weighted;

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nuevo ejercicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('nombre-ejercicio'),
              controller: nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: 'Las variantes son ejercicios distintos: '
                      '"Press plano (smith)" ≠ "(barra)"'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MuscleGroup>(
              key: const Key('grupo-muscular'),
              initialValue: grupo,
              decoration:
                  const InputDecoration(labelText: 'Grupo muscular'),
              items: [
                for (final g in MuscleGroup.values)
                  DropdownMenuItem(value: g, child: Text(g.label)),
              ],
              onChanged: (value) => setState(() => grupo = value),
            ),
            const SizedBox(height: 8),
            // Modalidad (ADR-0013): decide si las series piden peso o
            // lastre opcional, y el tratamiento estadístico.
            SegmentedButton<ExerciseModality>(
              key: const Key('modalidad'),
              segments: [
                for (final m in ExerciseModality.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {modalidad},
              onSelectionChanged: (val) =>
                  setState(() => modalidad = val.first),
              showSelectedIcon: false,
            ),
            TextField(
              key: const Key('nombres-historicos'),
              controller: historicos,
              decoration: const InputDecoration(
                  labelText: 'Nombres históricos (opcional)',
                  helperText: 'Separados por coma; vinculan series viejas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-ejercicio'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    ),
  );
  if (confirmado != true || !context.mounted) return null;

  if (grupo == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige un grupo muscular.')));
    return null;
  }

  final exerciseId = const Uuid().v4();
  final legacy = [
    for (final n in historicos.text.split(','))
      if (n.trim().isNotEmpty) n.trim(),
  ];
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(addExerciseProvider).handle(AddExercise(
          exerciseId: exerciseId,
          name: nombre.text,
          muscleGroup: grupo!,
          modality: modalidad,
          legacyNames: legacy,
        ));
  } on DomainException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  } on ConcurrencyException {
    messenger.showSnackBar(const SnackBar(
        content: Text('Conflicto de escritura, intenta de nuevo.')));
    return null;
  }
  return ExerciseSummary(
    exerciseId: exerciseId,
    name: nombre.text.trim(),
    muscleGroup: grupo!.name,
    modality: modalidad.name,
  );
}

/// Etiqueta humana de un grupo persistido como string; si el valor no
/// matchea el enum (no debería), se muestra crudo en vez de romper.
String muscleGroupLabel(String muscleGroup) {
  for (final g in MuscleGroup.values) {
    if (g.name == muscleGroup) return g.label;
  }
  return muscleGroup;
}
