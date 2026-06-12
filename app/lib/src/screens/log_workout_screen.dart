import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';
import 'package:uuid/uuid.dart';

import '../format.dart';
import '../providers.dart';
import '../widgets/exercise_picker.dart';
import 'workout_detail_screen.dart' show showSetCorrectionSheet;

/// Pantalla de loggeo. UI delgada (ADR-0002): lee el workout en curso de
/// una proyección y despacha comandos; ninguna regla de negocio vive acá
/// (las invariantes están en el agregado y llegan como DomainException).
class LogWorkoutScreen extends ConsumerStatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  ConsumerState<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends ConsumerState<LogWorkoutScreen> {
  ExerciseSummary? _exercise;
  final _weightCtrl = TextEditingController();
  final _reps = TextEditingController();
  final _restSeconds = TextEditingController();
  bool _isLbs = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _reps.dispose();
    _restSeconds.dispose();
    super.dispose();
  }

  /// Despacho con manejo uniforme de errores: los rechazos del dominio se
  /// muestran tal cual (sus mensajes ya son para humanos, ADR-0005).
  Future<void> _dispatch(Future<void> Function() command) async {
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

  void _logSet(String workoutId) {
    final exercise = _exercise;
    if (exercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elige un ejercicio.')));
      return;
    }
    final rawWeight =
        double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    final weightKg =
        rawWeight == null ? null : (_isLbs ? rawWeight * 0.453592 : rawWeight);
    final reps = int.tryParse(_reps.text);
    final rest = _restSeconds.text.trim().isEmpty
        ? null
        : int.tryParse(_restSeconds.text);
    if (weightKg == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peso y reps deben ser números.')));
      return;
    }
    _dispatch(() => ref.read(logSetProvider).handle(LogSet(
          workoutId: workoutId,
          exercise: exercise.name,
          exerciseId: exercise.exerciseId,
          weightKg: weightKg,
          reps: reps,
          restBeforeSeconds: rest,
        )));
    _reps.clear();
    _restSeconds.clear();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeWorkoutProvider);
    return switch (active) {
      AsyncData(:final value) =>
        value == null ? _idle(context) : _inProgress(context, value),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _idle(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        key: const Key('empezar'),
        icon: const Icon(Icons.fitness_center),
        label: const Text('Empezar entreno'),
        onPressed: () => _dispatch(() =>
            ref.read(startWorkoutProvider).handle(StartWorkout(const Uuid().v4()))),
      ),
    );
  }

  Widget _inProgress(BuildContext context, WorkoutSummary workout) {
    final setsAsync = ref.watch(workoutSetsProvider(workout.workoutId));
    final sets = switch (setsAsync) {
      AsyncData(:final value) => value,
      _ => const <SetSummary>[],
    };
    final recent = sets.reversed.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    child: _counter(
                        context, 'Inicio', formatDayTime(workout.startedAt))),
                Expanded(
                    child: _counter(context, 'Series', '${workout.setCount}')),
                Expanded(
                    child: _counter(context, 'Volumen',
                        '${formatKg(workout.totalVolumeKg)} kg')),
              ],
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          _recentSets(context, recent, workout.workoutId),
        ],
        const SizedBox(height: 16),
        ExercisePickerField(
          key: const Key('ejercicio'),
          selected: _exercise,
          onSelected: (exercise) async {
            setState(() => _exercise = exercise);
            final last = await ref
                .read(gymReadModelsProvider)
                .lastSetForExercise(exercise.exerciseId);
            if (!mounted) return;
            setState(() {
              _weightCtrl.text = last != null ? formatKg(last.weightKg) : '';
              _reps.text = last != null ? last.reps.toString() : '';
            });
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Unidad:', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('kg')),
                ButtonSegment(value: true, label: Text('lb')),
              ],
              selected: {_isLbs},
              onSelectionChanged: (val) =>
                  setState(() => _isLbs = val.first),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('peso'),
                controller: _weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Peso (${_isLbs ? "lb" : "kg"})',
                    border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('reps'),
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Reps', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('descanso'),
                controller: _restSeconds,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Descanso previo (s)',
                    hintText: 'opcional',
                    border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('registrar'),
          icon: const Icon(Icons.add),
          label: const Text('Registrar serie'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
          onPressed: () => _logSet(workout.workoutId),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const Key('terminar'),
          icon: const Icon(Icons.flag),
          label: const Text('Terminar entreno'),
          onPressed: () => _dispatch(() => ref
              .read(completeWorkoutProvider)
              .handle(CompleteWorkout(workout.workoutId))),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('descartar'),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Descartar entreno'),
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => _confirmarDescarte(workout.workoutId),
        ),
      ],
    );
  }

  Widget _recentSets(
      BuildContext context, List<SetSummary> recent, String workoutId) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onSecondaryContainer;
    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Últimas series',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: onContainer)),
            const SizedBox(height: 6),
            for (int i = 0; i < recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: onContainer.withAlpha(40)),
              // Solo la más reciente (índice 0) es eliminable con swipe.
              if (i == 0)
                Dismissible(
                  key: Key('set-${recent[i].position}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error, size: 20),
                  ),
                  onDismissed: (_) => _dispatch(() => ref
                      .read(removeLastSetProvider)
                      .handle(RemoveLastSet(workoutId))),
                  child: _setRow(context, recent[i], theme, onContainer,
                      onTap: () => showSetCorrectionSheet(
                          context, ref, workoutId, recent[i])),
                )
              else
                _setRow(context, recent[i], theme, onContainer,
                    onTap: () => showSetCorrectionSheet(
                        context, ref, workoutId, recent[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _setRow(BuildContext context, SetSummary s, ThemeData theme,
      Color onContainer, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${s.position}',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: onContainer),
            ),
          ),
          Expanded(
            child: Text(
              s.exercise,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: onContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${formatKg(s.weightKg)} kg × ${s.reps}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: onContainer,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _confirmarDescarte(String workoutId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar este entreno?'),
        content: const Text(
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
    if (confirmado != true || !mounted) return;
    await _dispatch(() =>
        ref.read(discardWorkoutProvider).handle(DiscardWorkout(workoutId)));
  }

  Widget _counter(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
