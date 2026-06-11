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

  @override
  Widget build(BuildContext context) {
    final exercises =
        ref.watch(exercisesProvider).value ?? const <ExerciseSummary>[];
    final filtered = [
      for (final e in exercises)
        if (normalizeExerciseName(e.name)
            .contains(normalizeExerciseName(_query)))
          e,
    ];
    return Padding(
      // El sheet sube con el teclado.
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
                      child: Text('El catálogo está vacío: creá el primero.'))
                  : ListView(
                      children: [
                        for (final exercise in filtered)
                          ListTile(
                            title: Text(exercise.name),
                            subtitle: Text(muscleGroupLabel(
                                exercise.muscleGroup)),
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
        const SnackBar(content: Text('Elegí un grupo muscular.')));
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
          legacyNames: legacy,
        ));
  } on DomainException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  } on ConcurrencyException {
    messenger.showSnackBar(const SnackBar(
        content: Text('Conflicto de escritura, intentá de nuevo.')));
    return null;
  }
  return ExerciseSummary(
    exerciseId: exerciseId,
    name: nombre.text.trim(),
    muscleGroup: grupo!.name,
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
