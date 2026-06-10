import 'dart:async';

import 'package:drift/drift.dart';

/// Reactividad para read models de SQL crudo (ADR-0008).
///
/// Los projectors notifican con `db.notifyUpdates({TableUpdate(tabla)})`;
/// este helper convierte esas notificaciones en un stream de re-queries:
/// emite el resultado inicial al suscribirse y vuelve a ejecutar [query]
/// cada vez que alguna de [tables] cambia. Es la pieza que los
/// StreamProviders de la UI envuelven.
///
/// Implementado con StreamController explícito (no `async*`): un generador
/// async suspendido en un await no puede cancelarse hasta su próximo
/// yield, y aquí el await típico es "esperar la próxima notificación",
/// que puede no llegar nunca — cancel() quedaría colgado.
///
/// Garantías:
/// - La suscripción a notificaciones ocurre ANTES de la query inicial:
///   una escritura concurrente con esa primera query no se pierde.
/// - Las queries no se solapan: notificaciones que llegan mientras una
///   query corre se coalescen en un único re-query posterior.
/// - Single-subscription; cada listener dispara sus propias queries.
Stream<T> watchQuery<T>(
  GeneratedDatabase db,
  Set<String> tables,
  Future<T> Function() query,
) {
  late StreamController<T> controller;
  StreamSubscription<void>? notifications;
  var running = false;
  var pending = false;

  Future<void> run() async {
    if (running) {
      pending = true;
      return;
    }
    running = true;
    do {
      pending = false;
      try {
        final result = await query();
        if (!controller.isClosed) controller.add(result);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    } while (pending && !controller.isClosed);
    running = false;
  }

  controller = StreamController<T>(
    onListen: () {
      notifications = db
          .tableUpdates(TableUpdateQuery.allOf(
            [for (final table in tables) TableUpdateQuery.onTableName(table)],
          ))
          .listen((_) => run());
      run();
    },
    onCancel: () => notifications?.cancel(),
  );
  return controller.stream;
}
