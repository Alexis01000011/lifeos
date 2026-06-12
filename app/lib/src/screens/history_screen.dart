import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';

import '../format.dart';
import '../providers.dart';
import '../widgets/exercise_picker.dart';
import 'workout_detail_screen.dart';

/// Historial: la estadística derivada del walking skeleton (volumen por
/// semana ISO) y la lista de entrenos. Lee proyecciones y despacha los
/// comandos compensatorios (ADR-0010): descartar y agregar serie olvidada.
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutDetailScreen(workout: workout),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (workout.isInProgress) const Chip(label: Text('en curso')),
                PopupMenuButton<String>(
                  key: Key('menu-${workout.workoutId}'),
                  onSelected: (action) => switch (action) {
                    'descartar' => _confirmarDescarte(context, ref, workout),
                    _ => _agregarSerieOlvidada(context, ref, workout),
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'descartar', child: Text('Descartar…')),
                    if (!workout.isInProgress)
                      const PopupMenuItem(
                          value: 'serie-olvidada',
                          child: Text('Agregar serie olvidada…')),
                  ],
                ),
              ],
            ),
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

  /// Mismo manejo de errores que la pantalla de loggeo: los rechazos del
  /// dominio ya vienen en lenguaje humano (ADR-0005).
  Future<void> _dispatch(
      BuildContext context, Future<void> Function() command) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await command();
    } on DomainException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on ConcurrencyException {
      messenger.showSnackBar(const SnackBar(
          content: Text('Conflicto de escritura, intenta de nuevo.')));
    }
  }

  Future<void> _confirmarDescarte(
      BuildContext context, WidgetRef ref, WorkoutSummary workout) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar este entreno?'),
        content: Text(
            '${formatDayTime(workout.startedAt)} · ${workout.setCount} series. '
            'Dejará de contar en el historial y las estadísticas. '
            'Los eventos quedan en el registro, pero no hay deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-descarte'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    await _dispatch(
        context,
        () => ref
            .read(discardWorkoutProvider)
            .handle(DiscardWorkout(workout.workoutId)));
  }

  Future<void> _agregarSerieOlvidada(
      BuildContext context, WidgetRef ref, WorkoutSummary workout) async {
    ExerciseSummary? ejercicio;
    final peso = TextEditingController();
    final reps = TextEditingController();
    final descanso = TextEditingController();

    final agregar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Serie olvidada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExercisePickerField(
                key: const Key('tardia-ejercicio'),
                selected: ejercicio,
                onSelected: (e) => setState(() => ejercicio = e),
              ),
              TextField(
                key: const Key('tardia-peso'),
                controller: peso,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
              ),
              TextField(
                key: const Key('tardia-reps'),
                controller: reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reps'),
              ),
              TextField(
                key: const Key('tardia-descanso'),
                controller: descanso,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Descanso previo (s)',
                    hintText: 'opcional'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirmar-tardia'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    if (agregar != true || !context.mounted) return;

    if (ejercicio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elige un ejercicio.')));
      return;
    }
    final pesoKg = double.tryParse(peso.text.replaceAll(',', '.'));
    final repeticiones = int.tryParse(reps.text);
    final descansoSegundos =
        descanso.text.trim().isEmpty ? null : int.tryParse(descanso.text);
    if (pesoKg == null || repeticiones == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peso y reps deben ser números.')));
      return;
    }
    await _dispatch(
        context,
        () => ref.read(addMissedSetProvider).handle(AddMissedSet(
              workoutId: workout.workoutId,
              exercise: ejercicio!.name,
              exerciseId: ejercicio!.exerciseId,
              weightKg: pesoKg,
              reps: repeticiones,
              restBeforeSeconds: descansoSegundos,
            )));
  }
}
