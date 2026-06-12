import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';

import '../providers.dart';
import '../widgets/exercise_picker.dart';

/// Catálogo de ejercicios (ADR-0011): listar, crear y renombrar. La carga
/// inicial es manual, guiada por docs/gym_inventario.md; durante el entreno
/// también se puede crear al vuelo desde el picker.
class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider);

    return Scaffold(
      body: switch (exercises) {
        AsyncData(:final value) =>
          value.isEmpty ? _empty(context) : _list(context, ref, value),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        key: const Key('nuevo-ejercicio-catalogo'),
        onPressed: () => showAddExerciseDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'El catálogo está vacío.\n\nCrea tus ejercicios con el botón + '
          '(el inventario de tu rutina es la guía).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _list(
      BuildContext context, WidgetRef ref, List<ExerciseSummary> exercises) {
    // Agrupar por grupo muscular (la lista ya viene ordenada).
    final Map<String, List<ExerciseSummary>> byGroup = {};
    for (final e in exercises) {
      (byGroup[e.muscleGroup] ??= []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        // Colapsados por default (feedback de uso real 2026-06-11): la
        // pantalla se navega por grupos, no deslizando la lista entera.
        for (final entry in byGroup.entries)
          ExpansionTile(
            initiallyExpanded: false,
            title: Text(
              muscleGroupLabel(entry.key),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary),
            ),
            children: [
              for (final exercise in entry.value)
                ListTile(
                  title: Text(exercise.name),
                  subtitle: exercise.isBodyweight
                      ? Text(ExerciseModality.bodyweight.label)
                      : null,
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editar(context, ref, exercise),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _editar(
      BuildContext context, WidgetRef ref, ExerciseSummary exercise) async {
    final nombre = TextEditingController(text: exercise.name);
    var grupo = MuscleGroup.values.byName(exercise.muscleGroup);
    var modalidad = ExerciseModality.values.byName(exercise.modality);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar ejercicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('renombrar-nombre'),
                controller: nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: 'El nombre anterior sigue vinculado a series pasadas',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MuscleGroup>(
                key: const Key('editar-grupo'),
                initialValue: grupo,
                decoration:
                    const InputDecoration(labelText: 'Grupo muscular'),
                items: [
                  for (final g in MuscleGroup.values)
                    DropdownMenuItem(value: g, child: Text(g.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => grupo = value);
                },
              ),
              const SizedBox(height: 8),
              SegmentedButton<ExerciseModality>(
                key: const Key('editar-modalidad'),
                segments: [
                  for (final m in ExerciseModality.values)
                    ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {modalidad},
                onSelectionChanged: (val) =>
                    setState(() => modalidad = val.first),
                showSelectedIcon: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirmar-editar'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmado != true || !context.mounted) return;

    final nombreCambiado = nombre.text.trim() != exercise.name;
    final grupoCambiado = grupo.name != exercise.muscleGroup;
    final modalidadCambiada = modalidad.name != exercise.modality;
    if (!nombreCambiado && !grupoCambiado && !modalidadCambiada) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (nombreCambiado) {
        await ref.read(renameExerciseProvider).handle(
              RenameExercise(
                  exerciseId: exercise.exerciseId, newName: nombre.text),
            );
      }
      if (grupoCambiado && context.mounted) {
        await ref.read(correctExerciseMuscleGroupProvider).handle(
              CorrectExerciseMuscleGroup(
                exerciseId: exercise.exerciseId,
                newMuscleGroup: grupo,
              ),
            );
      }
      if (modalidadCambiada && context.mounted) {
        await ref.read(correctExerciseModalityProvider).handle(
              CorrectExerciseModality(
                exerciseId: exercise.exerciseId,
                newModality: modalidad,
              ),
            );
      }
    } on DomainException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on ConcurrencyException {
      messenger.showSnackBar(const SnackBar(
          content: Text('Conflicto de escritura, intenta de nuevo.')));
    }
  }
}
