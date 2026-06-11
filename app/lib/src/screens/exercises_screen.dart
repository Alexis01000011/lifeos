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
          'El catálogo está vacío.\n\nCreá tus ejercicios con el botón + '
          '(el inventario de tu rutina es la guía).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _list(
      BuildContext context, WidgetRef ref, List<ExerciseSummary> exercises) {
    // La lista ya viene ordenada por grupo (orden del enum) y nombre.
    final children = <Widget>[];
    String? currentGroup;
    for (final exercise in exercises) {
      if (exercise.muscleGroup != currentGroup) {
        currentGroup = exercise.muscleGroup;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            muscleGroupLabel(currentGroup),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary),
          ),
        ));
      }
      children.add(ListTile(
        title: Text(exercise.name),
        trailing: const Icon(Icons.edit_outlined, size: 18),
        onTap: () => _renombrar(context, ref, exercise),
      ));
    }
    return ListView(
        padding: const EdgeInsets.only(bottom: 88), children: children);
  }

  Future<void> _renombrar(
      BuildContext context, WidgetRef ref, ExerciseSummary exercise) async {
    final nombre = TextEditingController(text: exercise.name);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar ejercicio'),
        content: TextField(
          key: const Key('renombrar-nombre'),
          controller: nombre,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Nombre',
              helperText:
                  'El nombre viejo sigue vinculado a las series pasadas'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-renombrar'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Renombrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(renameExerciseProvider).handle(RenameExercise(
          exerciseId: exercise.exerciseId, newName: nombre.text));
    } on DomainException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on ConcurrencyException {
      messenger.showSnackBar(const SnackBar(
          content: Text('Conflicto de escritura, intentá de nuevo.')));
    }
  }
}
