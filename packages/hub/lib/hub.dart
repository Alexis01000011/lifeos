/// Hub: agregación y correlación entre módulos, y futura pantalla
/// principal (VISION). Regla 3: solo conoce integration events — jamás
/// los agregados ni domain events de un módulo. Depende SOLO de core.
library hub;

export 'src/integration_events.dart';
export 'src/projectors.dart';
export 'src/read_model.dart';
