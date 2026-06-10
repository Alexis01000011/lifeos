/// Lado de escritura de CQRS: la UI no toca agregados ni el event store;
/// despacha comandos.
///
/// Un comando es una INTENCIÓN ("registra este workout") y puede ser
/// rechazado. Contraste con evento: un hecho ya ocurrido, irrechazable.
/// Convención de nombres: comandos en imperativo (LogWorkout),
/// eventos en pasado (WorkoutLogged).
abstract class Command {}

/// Un handler por comando. Orquesta: cargar agregado (repositorio) →
/// invocar método de negocio → save(). NO contiene reglas de dominio;
/// esas viven en el agregado.
abstract class CommandHandler<C extends Command> {
  Future<void> handle(C command);
}

/// Error de validación de dominio: el comando fue rechazado porque
/// violaría una invariante. La UI lo traduce a mensaje para el usuario.
class DomainException implements Exception {
  final String message;
  DomainException(this.message);

  @override
  String toString() => message;
}
