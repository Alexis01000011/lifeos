/// Formateo mínimo sin paquete intl: el esqueleto no necesita locales.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// '10/06 18:32' en hora local, a partir del occurredAt UTC.
String formatDayTime(DateTime utc) {
  final d = utc.toLocal();
  return '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// 'Semana del 08/06' a partir del week_start 'YYYY-MM-DD'.
String formatWeekStart(String weekStart) {
  final parts = weekStart.split('-');
  return 'Semana del ${parts[2]}/${parts[1]}';
}

/// Volumen sin decimales fantasma: 3840 → '3840', 102.5 → '102.5'.
String formatKg(double kg) =>
    kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// Carga × reps de una serie (ADR-0013): '80 kg × 10' la weighted,
/// '× 12' la corporal sin lastre, '+5 kg × 12' la corporal con lastre.
String formatSetLoad(double? weightKg, int reps, {bool isBodyweight = false}) {
  if (weightKg == null) return '× $reps';
  final prefix = isBodyweight ? '+' : '';
  return '$prefix${formatKg(weightKg)} kg × $reps';
}
