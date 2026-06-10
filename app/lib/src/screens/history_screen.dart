import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';

import '../format.dart';
import '../providers.dart';

/// Historial: la estadística derivada del walking skeleton (volumen por
/// semana ISO) y la lista de entrenos. Solo lee proyecciones.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    final weekly = ref.watch(weeklyVolumeProvider);

    if (history is AsyncError) {
      return Center(child: Text('Error: ${history.error}'));
    }
    if (history is! AsyncData<List<WorkoutSummary>> ||
        weekly is! AsyncData<List<WeeklyVolume>>) {
      return const Center(child: CircularProgressIndicator());
    }

    final workouts = history.value;
    final weeks = weekly.value;
    if (workouts.isEmpty) {
      return const Center(child: Text('Todavía no hay entrenos.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, 'Volumen semanal'),
        for (final week in weeks)
          ListTile(
            leading: const Icon(Icons.stacked_bar_chart),
            title: Text(formatWeekStart(week.weekStart)),
            trailing: Text('${formatKg(week.totalVolumeKg)} kg',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        const Divider(),
        _sectionTitle(context, 'Entrenos'),
        for (final workout in workouts)
          ListTile(
            leading: Icon(workout.isInProgress
                ? Icons.play_circle_outline
                : Icons.check_circle_outline),
            title: Text(formatDayTime(workout.startedAt)),
            subtitle: Text(
                '${workout.setCount} series · ${formatKg(workout.totalVolumeKg)} kg'),
            trailing: workout.isInProgress ? const Chip(label: Text('en curso')) : null,
          ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
