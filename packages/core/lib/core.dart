/// Hexágono interior: abstracciones de Event Sourcing + CQRS.
/// Cero dependencias de Flutter/Drift. Ver ADR-0001.
library core;

export 'src/aggregate_root.dart';
export 'src/command.dart';
export 'src/domain_event.dart';
export 'src/event_serialization.dart';
export 'src/event_store.dart';
export 'src/integration_event.dart';
export 'src/projection.dart';
export 'src/projection_engine.dart';
export 'src/repository.dart';
export 'src/time.dart';
