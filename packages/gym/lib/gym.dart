/// Módulo gym: bounded context de entrenamientos.
/// Regla de fronteras: depende SOLO de core. Sus domain events son
/// privados; lo que anuncia al resto del sistema sale como integration
/// events por el log de integración (src/integration.dart, ADR-0009).
library gym;

export 'src/commands.dart';
export 'src/events.dart';
export 'src/exercise_catalog.dart';
export 'src/integration.dart';
export 'src/projectors.dart';
export 'src/read_model.dart';
export 'src/workout.dart';
