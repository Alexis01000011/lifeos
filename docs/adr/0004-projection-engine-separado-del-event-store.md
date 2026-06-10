# ADR-0004: ProjectionEngine separado del event store

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Pregunta abierta de Fase 0: el wiring evento→projector, ¿vive dentro de la implementación Drift del `EventStore`, o en una pieza aparte (`ProjectionEngine`) que el store invoca? ADR-0001 fija que las proyecciones se actualizan en la misma transacción que el append; esta decisión es sobre quién conoce a los projectors, no sobre cuándo corren.

## Opciones consideradas

**A. El store Drift conoce la lista de projectors y los invoca.** Pro: una pieza menos, wiring directo. Con: mezcla dos responsabilidades (persistir y despachar); y el replay de la prueba ácida (Fase 2) necesitaría duplicar la lógica de despacho y checkpoints fuera del store, o contaminar al store con una API de replay que no es suya.

**B. `ProjectionEngine` aparte que el store invoca (elegida).** Pro: single responsibility — el store persiste, el engine despacha (filtrado por `handledEventTypes`, checkpoints, idempotencia); el mismo despacho sirve para las dos caras: append síncrono y replay (`reset()` + `readAll()`); testeable con projectors fake sin tocar Drift. Con: una pieza más de indirección.

## Decisión

Opción B. Razón decisiva: el replay de la prueba ácida es exactamente la otra cara del mismo despacho — con un engine se escribe una vez y la prueba ácida ejercita el mismo código que produce el estado en producción, que es justo lo que la hace creíble.

## Consecuencias

- `packages/core` gana `ProjectionEngine` (puro Dart, clase concreta): recibe los projectors registrados y el `ProjectionCheckpointStore`, expone despacho de envelopes y replay completo.
- La implementación Drift del `EventStore` no conoce projectors individuales: invoca al engine dentro de la transacción de append.
- El test de la prueba ácida (Fase 2) se construye sobre `reset()` de cada projector + replay del engine alimentado por `readAll()`.
- Costo aceptado: una abstracción más en core; se mantiene chica (orquestación, cero lógica de dominio).
