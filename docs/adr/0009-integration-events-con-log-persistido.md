# ADR-0009: integration events con log persistido (outbox) y despacho por el cable

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Fase 4: gym publica su primer integration event y el hub lo consume (VISION Reglas 2-4). La pregunta central: ¿qué es físicamente un integration event? De la respuesta dependen el replay del hub, la inmutabilidad del contrato publicado y el camino a sync multi-dispositivo.

## Opciones consideradas

**A. Log persistido — outbox en la database compuesta (elegida).** Tabla `integration_events` propia; la policy del módulo publica dentro de la transacción del append; el hub proyecta desde ese log con sus checkpoints. Pro: lo publicado es historia inmutable (cambiar la traducción no reescribe lo ya emitido — Regla 4 de verdad, no de papel); replay del hub independiente de los módulos; patrón outbox de industria; base natural para sync. Con: un segundo log que mantener y la obligación de que publicar jamás ocurra fuera de la transacción del append.

**B. Efímeros, re-derivados en replay.** La traducción domain→integration es función pura que corre en vivo y en rebuild; nada nuevo se persiste. Pro: fuente de verdad única estricta, cero schema. Con: cambiar el traductor reescribe la historia publicada — el "contrato versionado" queda en papel; y el rebuild del hub ejecuta código de los módulos productores.

**C. Bus en memoria sin log.** Pub/sub puro in-process. Con: las proyecciones del hub no son reconstruibles (rompe la prueba ácida del hub); descartada rápido.

## Decisión

Opción A. Razón decisiva: es la única donde "API pública versionada" significa algo — lo publicado no depende del código de hoy. Alexis la eligió con los tradeoffs sobre la mesa.

## Consecuencias

- **Tipos separados**: `IntegrationEvent` no es `DomainEvent`; el sistema de tipos impide cruzar logs. `EventTypeRegistry<E>` se volvió genérico — mismo mecanismo de versionado (weak schema + upcasters), instancias separadas.
- **La policy corre como un `Projector` más** del ProjectionEngine (misma transacción, misma guarda de checkpoint), pero con semántica de outbox: idempotente por `UNIQUE(causation_event_id)` y `reset()` no-op — **lo publicado no se despublica**; un rebuild reconstruye modelos de lectura, no reescribe la API emitida.
- **El despacho en vivo pasa por el cable** (serializar → deserializar vía registry): el suscriptor recibe SU representación del contrato, nunca el objeto del productor. Live y replay entregan lo mismo; la frontera schema-first es real. (Lección de implementación: la versión ingenua pasaba el objeto del productor y el cast del hub explotaba — el test del flujo completo lo cazó.)
- **Contratos huérfanos**: un tipo sin consumidor registrado se persiste sin despachar y el replay lo salta (`registry.knows`); una VERSIÓN inalcanzable de un tipo conocido sigue explotando (bug de upcasters). Publicar no exige que alguien escuche.
- **`IntegrationProjectionEngine` es un espejo deliberado** de ProjectionEngine (envelopes y espacios de secuencia distintos); si la duplicación duele al crecer, unificarlos con genéricos será un ADR nuevo.
- **El contrato canónico es JSON** en `docs/integration-events.md`; productor y consumidores duplican la clase Dart a propósito (Regla 1: el hub no importa módulos).
- Nace `packages/hub` (depende solo de core) con su propia prueba ácida: reset + replay del log de integración ≡ estado idéntico.
- `isoWeekStartUtc` se movió a core como shared kernel mínimo (gym y hub bucketizan igual); gym lo re-exporta.
