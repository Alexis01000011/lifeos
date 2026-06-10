# core — abstracciones ES+CQRS

Siete archivos, cero dependencias externas (ni Drift ni Flutter): esto es el **hexágono interior**. Drift aparece recién en el adaptador `core_drift` (ADR-0006), que implementa `EventStore` y `ProjectionCheckpointStore`.

## Mapa

| Archivo | Qué define | Decisión que encarna |
|---|---|---|
| `domain_event.dart` | `DomainEvent`, `StreamId`, `EventEnvelope` | Evento (qué pasó) separado de metadata (dónde/cuándo/orden). `globalSequence` da orden total para proyecciones. |
| `event_store.dart` | `EventStore`, `ConcurrencyException` | Append-only, atómico, concurrencia optimista. Las proyecciones síncronas son detalle de la implementación Drift, no del contrato. |
| `aggregate_root.dart` | `AggregateRoot` | Mutación en dos fases: `raise()` para hechos nuevos, `apply()` puro y determinista para ambos caminos. Agregados chicos (Workout, no GymHistory). |
| `repository.dart` | `AggregateRepository<T>` | Solo `load`/`save`. El `expectedVersion` se calcula solo. |
| `command.dart` | `Command`, `CommandHandler`, `DomainException` | La UI despacha intenciones; las reglas viven en el agregado, el handler solo orquesta. |
| `projection.dart` | `Projector`, `ProjectionCheckpointStore` | Contrato async aunque la ejecución hoy sea síncrona. `reset()` + replay = prueba ácida de fuente de verdad única. |
| `projection_engine.dart` | `ProjectionEngine` | ADR-0004: el store persiste, el engine despacha (filtro por eventType, checkpoints, idempotencia). El mismo despacho sirve al append síncrono y a `rebuild()` — la mecánica de la prueba ácida. |
| `event_serialization.dart` | `EventTypeRegistry`, `DefaultEventTypeRegistry`, `Upcaster` | Versionado: weak schema por defecto, upcasters encadenados cuando no alcance. `eventType` string estable, nunca `runtimeType`. |

## Flujo completo (el walking skeleton lo recorre entero)

UI → `Command` → `CommandHandler` → `Repository.load()` → método de negocio del agregado → `raise()` → `Repository.save()` → `EventStore.append()` —(misma transacción Drift)→ `Projector.project()` → tabla de lectura → stream Drift → Riverpod `StreamProvider` → UI se redibuja.

## Preguntas cerradas (2026-06-10)

1. **`eventId`/`occurredAt` se generan en el `append` del store** → ADR-0003. `raise()` queda puro; el tiempo de negocio, cuando haga falta (registro en diferido), es campo del payload del evento.
2. **Wiring evento→projector en un `ProjectionEngine` aparte** → ADR-0004. El store persiste, el engine despacha; el replay de la prueba ácida reutiliza el mismo despacho.
3. **Snapshots: sin interfaz hasta que un stream duela.** Ya estaba decidido en ADR-0001; confirmado.
4. **Integration events quedan fuera de Fase 0**, llegan en Fase 4 como indica el roadmap. Vigilar que las abstracciones de Fase 0 no horneen supuestos que estorben (p. ej. que `EventTypeRegistry` asuma que todo evento es de dominio).
5. **`DomainException` con string por ahora** → ADR-0005. Migración a errores tipados por módulo al crear el segundo módulo (registrado en ROADMAP, Hito 3).

## Críticas que yo mismo le haría

- ~~`rehydrate()` confía en que los envelopes llegan ordenados; el contrato de `readStream` debería decirlo explícitamente.~~ Resuelto 2026-06-10: el orden de lectura es ahora invariante explícito del contrato de `EventStore`.
- `AggregateRepository` concreto (no interfaz). Si algún día hay snapshots, se vuelve interfaz con implementación alternativa. Por ahora YAGNI.
- No hay `CommandBus`/mediator: la UI conocerá handlers concretos vía Riverpod. Menos indirección; revisar si molesta en Fase 4.
