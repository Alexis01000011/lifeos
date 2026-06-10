# ADR-0003: eventId y occurredAt se generan en el append del event store

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Pregunta abierta de Fase 0: ¿quién genera la metadata de persistencia (`eventId`, `occurredAt`) — el agregado al hacer `raise()`, o la infraestructura al hacer `append()`? La restricción dura es que `apply()` debe ser puro y determinista (ADR-0001: el replay depende de ello), y `raise()` debería serlo también para que los tests de dominio no necesiten fakes.

## Opciones consideradas

**A. En el `append` del store (elegida).** El agregado emite `DomainEvent`s "desnudos"; el `EventEnvelope` (con eventId, occurredAt, streamVersion, globalSequence) nace completo y de una sola vez en infraestructura. Pro: `raise()` queda puro, los agregados no arrastran reloj/uuid inyectados, y el envelope nunca existe en estado incompleto. Con: `occurredAt` pasa a significar "cuándo se persistió", no "cuándo ocurrió el hecho".

**B. En `raise()` con reloj y generador de uuid inyectados.** Pro: el timestamp es semánticamente del hecho, no del guardado. Con: dos dependencias inyectadas en cada agregado que el 99% del tiempo son ruido; y el beneficio se diluye porque el tiempo de negocio real lo va a necesitar igual el payload — registrar un entreno en diferido ("entrené hace 3 horas") exige un campo propio del evento (p. ej. `WorkoutLogged.performedAt`), nunca la metadata del envelope.

## Decisión

Opción A. Razón decisiva: el tiempo de negocio vivirá como campo del evento cuando un dominio lo necesite (caso registro en diferido, previsto para Hito 2); por tanto `occurredAt` del envelope es metadata de auditoría de persistencia y le corresponde a la infraestructura generarla.

## Consecuencias

- `raise()` y `apply()` quedan puros; los agregados no reciben reloj ni uuid, y sus tests no necesitan fakes de tiempo.
- Se redefine la semántica documentada de `EventEnvelope.occurredAt`: timestamp de persistencia (auditoría), no del hecho de dominio. El dartdoc se corrige en este mismo cambio.
- Regla derivada: si un evento necesita tiempo de negocio, va como campo del payload (`performedAt` y similares), con la misma disciplina de weak schema que el resto.
- La implementación Drift del `EventStore` es la única responsable de generar `eventId` (UUID) y `occurredAt` dentro de `append`.
