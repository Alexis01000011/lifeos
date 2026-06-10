import 'domain_event.dart';

/// Base de todo agregado. Un agregado es la frontera de consistencia:
/// las invariantes del dominio se validan aquí y solo aquí.
///
/// Patrón de mutación en dos fases:
/// - Los métodos de negocio (p. ej. logSet()) VALIDAN y llaman a [raise].
/// - [raise] registra el evento como pendiente y delega en [apply].
/// - [apply] es la ÚNICA que muta estado, sin validar nada (los eventos
///   persistidos ya pasaron validación cuando ocurrieron; re-validarlos
///   en replay rompería la rehidratación si las reglas cambian).
///
/// Regla de oro: apply() debe ser determinista y sin efectos secundarios.
/// Nada de DateTime.now(), random, ni I/O dentro de apply().
abstract class AggregateRoot {
  final String id;
  AggregateRoot(this.id);

  /// Nombre estable del tipo (forma el StreamId junto con [id]).
  String get aggregateType;

  int _version = 0;
  final List<DomainEvent> _uncommitted = [];

  /// streamVersion del último evento aplicado. Se pasa como
  /// expectedVersion al EventStore (concurrencia optimista).
  int get version => _version;

  List<DomainEvent> get uncommittedEvents => List.unmodifiable(_uncommitted);

  /// Mutación de estado por tipo de evento. Implementada por cada agregado
  /// (típicamente un switch sobre el tipo).
  void apply(DomainEvent event);

  /// Camino de escritura: hecho nuevo, validado por el método de negocio.
  void raise(DomainEvent event) {
    apply(event);
    _version++;
    _uncommitted.add(event);
  }

  /// Camino de lectura: reconstrucción desde el event store.
  void rehydrate(Iterable<EventEnvelope> history) {
    for (final envelope in history) {
      apply(envelope.event);
      _version = envelope.streamVersion;
    }
  }

  /// Lo llama el repositorio tras un append exitoso.
  void markCommitted() => _uncommitted.clear();
}
