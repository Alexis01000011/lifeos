/// Módulo gym: bounded context de entrenamientos.
/// Regla de fronteras: depende SOLO de core. Sus domain events son
/// privados; lo que anuncie al resto del sistema saldrá como integration
/// events vía el hub (Fase 4).
library gym;

export 'src/commands.dart';
export 'src/events.dart';
export 'src/workout.dart';
