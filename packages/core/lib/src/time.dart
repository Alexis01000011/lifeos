/// Calendario determinista compartido (shared kernel): bucketing usado por
/// read models de más de un bounded context (gym, hub). Vive en core para
/// que dos módulos no dupliquen —y desincronicen— la misma aritmética.

/// Lunes (ISO) de la semana de [moment], como YYYY-MM-DD.
///
/// Bucketiza en UTC: simplificación aceptada del esqueleto (un entreno
/// nocturno puede caer en el día UTC siguiente). Se revisará en Hito 2
/// junto con el tiempo de negocio (ADR-0003).
String isoWeekStartUtc(DateTime moment) {
  final utc = moment.toUtc();
  final date = DateTime.utc(utc.year, utc.month, utc.day);
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(monday.year, 4)}-${pad(monday.month, 2)}-${pad(monday.day, 2)}';
}
