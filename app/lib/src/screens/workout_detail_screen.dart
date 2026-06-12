import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';

import '../format.dart';
import '../providers.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  final WorkoutSummary workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(workoutSetsProvider(workout.workoutId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDayTime(workout.startedAt)),
            Text(
              '${workout.setCount} series · ${formatKg(workout.totalVolumeKg)} kg',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: switch (setsAsync) {
        AsyncData(:final value) when value.isEmpty =>
          const Center(child: Text('Sin series registradas.')),
        AsyncData(:final value) => ListView.separated(
            itemCount: value.length,
            separatorBuilder: (context, i) {
              final sameExercise = value[i].exercise == value[i + 1].exercise;
              return sameExercise
                  ? const Divider(indent: 56, endIndent: 16, height: 1)
                  : Divider(
                      height: 12,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    );
            },
            itemBuilder: (context, i) =>
                _setTile(context, ref, value[i], workout.workoutId),
          ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _setTile(
      BuildContext context, WidgetRef ref, SetSummary set, String workoutId) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SizedBox(
        width: 32,
        child: Center(
          child: Text(
            '#${set.position}',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(set.exercise)),
          if (set.isLate)
            Chip(
              label: const Text('tardía'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
        ],
      ),
      subtitle: set.restBeforeSeconds != null
          ? Text('Descanso previo: ${set.restBeforeSeconds} s')
          : null,
      trailing: Text(
        formatSetLoad(set.weightKg, set.reps, isBodyweight: set.isBodyweight),
        style: theme.textTheme.titleSmall,
      ),
      onTap: () => showSetCorrectionSheet(context, ref, workoutId, set),
    );
  }
}

/// Bottom sheet de corrección de serie. Reutilizable desde LogWorkoutScreen.
Future<void> showSetCorrectionSheet(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
  SetSummary set,
) async {
  // Serie corporal (ADR-0013): el peso es lastre opcional — el campo
  // vacío significa "sin carga externa" y viaja como null.
  final isBodyweight = set.isBodyweight;
  final weightCtrl = TextEditingController(
      text: set.weightKg != null ? formatKg(set.weightKg!) : '');
  final repsCtrl = TextEditingController(text: set.reps.toString());

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(sheetCtx).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Corregir serie #${set.position} — ${set.exercise}',
            style: Theme.of(sheetCtx).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isBodyweight ? 'Lastre (kg)' : 'Peso (kg)',
                    hintText: isBodyweight ? 'opcional' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reps',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
            onPressed: () async {
              final weightText = weightCtrl.text.trim();
              final weightKg =
                  double.tryParse(weightText.replaceAll(',', '.'));
              final reps = int.tryParse(repsCtrl.text);
              if (reps == null ||
                  (weightKg == null &&
                      (!isBodyweight || weightText.isNotEmpty))) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isBodyweight
                        ? 'Reps debe ser un número (y el lastre, si lo pones).'
                        : 'Peso y reps deben ser números.')));
                return;
              }
              Navigator.of(sheetCtx).pop();
              try {
                await ref.read(correctSetProvider).handle(CorrectSet(
                      workoutId: workoutId,
                      position: set.position,
                      weightKg: weightKg,
                      reps: reps,
                    ));
              } on DomainException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Guardar corrección'),
          ),
        ],
      ),
    ),
  );

  weightCtrl.dispose();
  repsCtrl.dispose();
}
