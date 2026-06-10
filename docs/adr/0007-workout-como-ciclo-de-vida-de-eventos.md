# ADR-0007: el workout se modela como ciclo de vida de eventos, no como evento único

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Fase 1 (gym write-side): hay que elegir la granularidad de los domain events del workout. La decisión pesa porque los eventos persistidos son contrato para siempre, y porque el Hito 2 exige explícitamente "registro cómodo de series/reps/peso **durante** el entreno" — la app se usa en el gimnasio, serie por serie, con una mano.

## Opciones consideradas

**A. Ciclo de vida (elegida).** `WorkoutStarted` → `SetLogged` (n veces) → `WorkoutCompleted`. Pro: refleja cómo se entrena de verdad y es la forma que el MVP necesita — no habrá remodelado en Hito 2; el agregado gana invariantes reales desde ya (no se agregan series a un workout completado; no se completa sin series). Con: más eventos e invariantes en el esqueleto, y la UI de Fase 3 debe manejar un workout "en curso" en vez de un formulario único.

**B. Evento único.** `WorkoutLogged` con ejercicios y series adentro, registrado al terminar. Pro: esqueleto y UI mínimos. Con: remodelado casi seguro en semanas, con eventos de la forma vieja conviviendo con los nuevos — deuda elegida sin necesidad.

**C. Híbrido.** Ciclo de vida + `WorkoutLogged` para registro en diferido ("entrené hace 3 horas"). Pro: cubre ambos modos de uso. Con: dos caminos de escritura que mantener cuando el esqueleto solo necesita uno; el diferido se puede agregar después de forma aditiva sin romper nada.

## Decisión

Opción A. Razón decisiva: el Hito 2 ya fija el modo de uso real (registro en vivo); modelar distinto en el esqueleto sería optimizar la fase descartable a costa de la persistente.

**Payload de `SetLogged` (v1):** ejercicio (texto libre — el catálogo llega en Hito 2), peso en kg (0 válido: peso corporal), reps, y `restBeforeSeconds` opcional (segundos descansados antes de la serie; null si no se midió). El descanso entra desde el primer evento por decisión de Alexis: lo cronometra y quiere esa estadística sin huecos en el historial.

## Consecuencias

- Eventos persistidos desde hoy: `gym.workout_started` v1, `gym.set_logged` v1, `gym.workout_completed` v1. Cambiarlos es asunto de weak schema/upcasters, ya no de refactor.
- El agregado `Workout` es chico (un entrenamiento, no el historial) y sus streams cortos (decenas de eventos), consistente con ADR-0001.
- La UI de Fase 3 necesita la noción de workout en curso (empezar / agregar serie / terminar).
- El registro en diferido (Hito 2) se agregará de forma aditiva (campo de tiempo de negocio en payload, ADR-0003), sin tocar estos eventos.
- RPE, notas y demás métricas futuras entran como campos opcionales con default (weak schema), sin upcaster.
