import 'dart:async';

import 'domain_event.dart';

/// Lado de lectura de CQRS. Una proyección transforma eventos en un modelo
/// de lectura (tablas Drift que la UI consulta vía streams).
///
/// CONTRATO ASYNC A PROPÓSITO (decisión 2026-06-09): aunque hoy las
/// proyecciones se actualizan en la misma transacción que el append
/// (concesión local-first), la interfaz devuelve FutureOr para que nada
/// del dominio ni de la UI asuma sincronía. Si mañana hay versión web con
/// sync y las proyecciones pasan a ser asíncronas, este contrato no cambia.
abstract class Projector {
  /// Nombre estable, p. ej. 'gym.workout_history'. Identifica su checkpoint
  /// y sus tablas.
  String get name;

  /// Tipos de evento que le interesan (por eventType, no por Type de Dart).
  Set<String> get handledEventTypes;

  /// Aplica un evento al modelo de lectura.
  ///
  /// DEBE ser idempotente: proyectar el mismo envelope dos veces tiene que
  /// dejar el mismo resultado (en replay o reintentos pasará). El
  /// globalSequence del envelope sirve como guarda.
  FutureOr<void> project(EventEnvelope envelope);

  /// Borra el modelo de lectura por completo. Junto con un readAll() del
  /// event store, permite reconstruir desde cero. Esta es la prueba ácida
  /// de que los eventos son la única fuente de verdad.
  Future<void> reset();
}

/// Checkpoint: hasta qué globalSequence ha procesado cada proyección.
/// Con proyecciones síncronas siempre estará al día; existe porque el
/// contrato no asume sincronía (replay parcial, futuras proyecciones async).
abstract class ProjectionCheckpointStore {
  Future<int> getCheckpoint(String projectorName);
  Future<void> saveCheckpoint(String projectorName, int globalSequence);
}
