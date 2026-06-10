import 'aggregate_root.dart';
import 'domain_event.dart';
import 'event_store.dart';

/// Pegamento entre agregados y event store. Genérico: un repositorio
/// por tipo de agregado, parametrizado con su fábrica.
///
/// No hay update() ni delete(): en ES solo existe "cargar" y "guardar
/// los hechos nuevos".
class AggregateRepository<T extends AggregateRoot> {
  final EventStore _store;
  final String _aggregateType;

  /// Fábrica de instancias vacías listas para rehidratar.
  final T Function(String id) _factory;

  AggregateRepository(this._store, this._aggregateType, this._factory);

  /// Devuelve null si el stream no existe (el agregado nunca fue creado).
  Future<T?> load(String id) async {
    final history =
        await _store.readStream(StreamId(_aggregateType, id));
    if (history.isEmpty) return null;
    final aggregate = _factory(id)..rehydrate(history);
    return aggregate;
  }

  /// Persiste los eventos pendientes con concurrencia optimista.
  /// expectedVersion = versión rehidratada = version actual - pendientes.
  Future<void> save(T aggregate) async {
    final pending = aggregate.uncommittedEvents;
    if (pending.isEmpty) return;
    await _store.append(
      StreamId(_aggregateType, aggregate.id),
      pending,
      expectedVersion: aggregate.version - pending.length,
    );
    aggregate.markCommitted();
  }
}
