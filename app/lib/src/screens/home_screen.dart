import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hub/hub.dart';

import '../providers.dart';

/// Inicio: el embrión de la pantalla principal de VISION — estadísticas
/// del hub y punto de entrada hacia los módulos. Solo lee proyecciones
/// del hub (Regla 3 llega hasta la UI: nada de read models de gym aquí).
class HomeScreen extends ConsumerWidget {
  /// Atajo hacia el módulo: tocar la estadística navega (VISION: la
  /// pantalla principal es visor y redireccionador).
  final VoidCallback onOpenGym;

  const HomeScreen({super.key, required this.onOpenGym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyWorkoutCountsProvider);
    return switch (weekly) {
      AsyncData(:final value) => _stats(context, value),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _stats(BuildContext context, List<WeeklyWorkoutCount> weeks) {
    final theme = Theme.of(context);
    final thisWeek = isoWeekStartUtc(DateTime.now());
    final count = weeks
        .where((w) => w.weekStart == thisWeek)
        .map((w) => w.workoutCount)
        .firstOrNull ??
        0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: InkWell(
            key: const Key('stat-gym'),
            onTap: onOpenGym,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.fitness_center,
                      size: 40, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entrenos esta semana',
                            style: theme.textTheme.labelLarge),
                        Text('$count', style: theme.textTheme.displaySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
