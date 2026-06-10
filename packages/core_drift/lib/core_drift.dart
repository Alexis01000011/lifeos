/// Adaptador de persistencia del hexágono: implementa los puertos
/// EventStore y ProjectionCheckpointStore de `core` sobre Drift/SQLite.
///
/// Diseño (ADR-0006): SQL crudo (customSelect/customInsert) sobre la
/// GeneratedDatabase que la app shell compone. Una sola database para
/// eventos y proyecciones = una sola transacción zone-based, que es lo
/// que hace atómico el "append + proyecciones síncronas" de ADR-0001.
library core_drift;

export 'src/drift_checkpoint_store.dart';
export 'src/drift_event_store.dart';
export 'src/schema.dart';
export 'src/watch_query.dart';
