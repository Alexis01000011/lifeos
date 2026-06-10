# Fase 0 — Abstracciones del core (borrador para crítica)

Borrador del 2026-06-09. Seis archivos, cero dependencias externas (ni Drift ni Flutter): esto es el **hexágono interior**. Drift aparece recién en las implementaciones de `EventStore`, `Projector` y `ProjectionCheckpointStore`.

## Mapa

| Archivo | Qué define | Decisión que encarna |
|---|---|---|
| `domain_event.dart` | `DomainEvent`, `StreamId`, `EventEnvelope` | Evento (qué pasó) separado de metadata (dónde/cuándo/orden). `globalSequence` da orden total para proyecciones. |
| `event_store.dart` | `EventStore`, `ConcurrencyException` | Append-only, atómico, concurrencia optimista. Las proyecciones síncronas son detalle de la implementación Drift, no del contrato. |
| `aggregate_root.dart` | `AggregateRoot` | Mutación en dos fases: `raise()` para hechos nuevos, `apply()` puro y determinista para ambos caminos. Agregados chicos (Workout, no GymHistory). |
| `repository.dart` | `AggregateRepository<T>` | Solo `load`/`save`. El `expectedVersion` se calcula solo. |
| `command.dart` | `Command`, `CommandHandler`, `DomainException` | La UI despacha intenciones; las reglas viven en el agregado, el handler solo orquesta. |
| `projection.dart` | `Projector`, `ProjectionCheckpointStore` | Contrato async aunque la ejecución hoy sea síncrona. `reset()` + replay = prueba ácida de fuente de verdad única. |
| `event_serialization.dart` | `EventTypeRegistry`, `Upcaster` | Versionado: weak schema por defecto, upcasters encadenados cuando no alcance. `eventType` string estable, nunca `runtimeType`. |

## Flujo completo (el walking skeleton lo recorre entero)

UI → `Command` → `CommandHandler` → `Repository.load()` → método de negocio del agregado → `raise()` → `Repository.save()` → `EventStore.append()` —(misma transacción Drift)→ `Projector.project()` → tabla de lectura → stream Drift → Riverpod `StreamProvider` → UI se redibuja.

## Preguntas abiertas (para discutir antes de implementar)

1. **¿Dónde se generan `eventId` y `occurredAt`?** Propuesta: en el `append` del store (infraestructura) para mantener `raise()` puro. Alternativa: en `raise()`, pero entonces el agregado necesita un reloj/uuid inyectado.
2. **¿El wiring evento→projector vive en el EventStore de Drift o en un `ProjectionEngine` aparte que el store invoca?** Lo segundo es más limpio pero es una pieza más.
3. **Snapshots**: el contrato `readStream(fromVersion)` ya deja la puerta abierta. ¿Confirmamos que no hay interfaz de snapshot hasta que un stream duela?
4. **Integration events (Fase 4)**: el hub necesitará un bus para eventos entre módulos. Deliberadamente fuera de Fase 0 — ¿de acuerdo en que el walking skeleton no lo necesita?
5. **`DomainException` con string**: ¿suficiente, o prefieres errores tipados por módulo desde ya?

## Críticas que yo mismo le haría

- `rehydrate()` confía en que los envelopes llegan ordenados; el contrato de `readStream` debería decirlo explícitamente (lo dice implícitamente, mala señal).
- `AggregateRepository` concreto (no interfaz). Si algún día hay snapshots, se vuelve interfaz con implementación alternativa. Por ahora YAGNI.
- No hay `CommandBus`/mediator: la UI conocerá handlers concretos vía Riverpod. Menos indirección; revisar si molesta en Fase 4.
