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
            itemBuilder: (context, i) => _setTile(context, value[i]),
          ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _setTile(BuildContext context, SetSummary set) {
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
        '${formatKg(set.weightKg)} kg × ${set.reps}',
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}
