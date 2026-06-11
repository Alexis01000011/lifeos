# Integration events — contratos públicos entre módulos

Este documento ES el contrato (schema-first): el productor y cada consumidor tienen su propia clase Dart, pero lo que obliga es el JSON descrito aquí. Cambiar un contrato publicado = cambiar API pública: weak schema (campos nuevos opcionales con default) y, si no alcanza, upcaster + bump de versión, con más conservadurismo que en domain events (VISION Regla 4, ADR-0009).

Mecánica: log persistido `integration_events` en la database compuesta (patrón outbox). Publicar comparte la transacción del append del domain event causante; un domain event causa a lo sumo una publicación (idempotencia por `causation_event_id`). Lo publicado no se despublica.

---

## `gym.workout_completed` — v1

| | |
|---|---|
| **Productor** | gym (`PublishWorkoutCompletedPolicy`, al persistirse el domain event homónimo) |
| **Consumidores** | hub (`HubWorkoutsProjector` → "entrenos esta semana: N") |
| **Semántica** | Un entrenamiento fue completado. Se emite exactamente una vez por workout (el agregado no permite completar dos veces). |

**Payload v1:**

```json
{
  "workout_id": "uuid del workout",
  "completed_at": "2026-06-10T18:00:00.000Z"
}
```

- `workout_id` — string. Identidad del workout en gym; para el consumidor es un id opaco (correlación/dedup), no una invitación a leer datos de gym.
- `completed_at` — string, ISO-8601 UTC. Tiempo de negocio del contrato. Hoy coincide con el momento de persistencia; cuando gym soporte registro en diferido (Hito 2), pasará a ser la hora real del entreno **sin cambiar el contrato**.

Deliberadamente NO incluye series ni volumen: el contrato más chico que sirve al consumidor actual. Agregar campos después es barato (weak schema); quitarlos es romper consumidores.

---

## `gym.workout_discarded` — v1

| | |
|---|---|
| **Productor** | gym (`PublishWorkoutDiscardedPolicy`, al persistirse el domain event homónimo **solo si el workout estaba completado** — un descarte en curso nunca fue anunciado) |
| **Consumidores** | hub (`HubWorkoutsProjector` → deja de contar ese workout) |
| **Semántica** | Compensatorio (ADR-0010): anula al `gym.workout_completed` del mismo `workout_id`. Lo publicado no se despublica; se publica la corrección. A lo sumo uno por workout (el agregado no permite descartar dos veces). |

**Payload v1:**

```json
{
  "workout_id": "uuid del workout",
  "discarded_at": "2026-06-10T21:00:00.000Z"
}
```

- `workout_id` — string. El mismo id opaco que anunció el `workout_completed` a anular.
- `discarded_at` — string, ISO-8601 UTC. Cuándo se descartó (tiempo de la corrección, no del entreno).

Deliberadamente NO incluye la semana ni datos del entreno original: cada consumidor guarda el estado que necesita para revertir lo suyo (el hub, su fila workout→semana). Un consumidor que no reconozca el `workout_id` lo ignora sin error.
