import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym.dart';
import 'package:uuid/uuid.dart';

import '../format.dart';
import '../providers.dart';

/// Pantalla de loggeo. UI delgada (ADR-0002): lee el workout en curso de
/// una proyección y despacha comandos; ninguna regla de negocio vive acá
/// (las invariantes están en el agregado y llegan como DomainException).
class LogWorkoutScreen extends ConsumerStatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  ConsumerState<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends ConsumerState<LogWorkoutScreen> {
  final _exercise = TextEditingController();
  final _weightKg = TextEditingController();
  final _reps = TextEditingController();
  final _restSeconds = TextEditingController();

  @override
  void dispose() {
    _exercise.dispose();
    _weightKg.dispose();
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
          content: Text('Conflicto de escritura, intentá de nuevo.')));
    }
  }

  void _logSet(String workoutId) {
    final weightKg = double.tryParse(_weightKg.text.replaceAll(',', '.'));
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
          exercise: _exercise.text,
          weightKg: weightKg,
          reps: reps,
          restBeforeSeconds: rest,
        )));
    _reps.clear(); // ejercicio y peso suelen repetirse entre series
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _counter(context, 'Inicio', formatDayTime(workout.startedAt)),
                _counter(context, 'Series', '${workout.setCount}'),
                _counter(
                    context, 'Volumen', '${formatKg(workout.totalVolumeKg)} kg'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('ejercicio'),
          controller: _exercise,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Ejercicio', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('peso'),
                controller: _weightKg,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Peso (kg)', border: OutlineInputBorder()),
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
                    labelText: 'Descanso (s)', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('registrar'),
          icon: const Icon(Icons.add),
          label: const Text('Registrar serie'),
          onPressed: () => _logSet(workout.workoutId),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('terminar'),
          icon: const Icon(Icons.flag),
          label: const Text('Terminar entreno'),
          onPressed: () => _dispatch(() => ref
              .read(completeWorkoutProvider)
              .handle(CompleteWorkout(workout.workoutId))),
        ),
      ],
    );
  }

  Widget _counter(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
