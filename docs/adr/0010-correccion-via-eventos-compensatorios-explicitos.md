# ADR-0010: corrección de errores vía eventos compensatorios explícitos

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Primer día de uso real (Hito 1) dejó errores en el event store del A71: dos entrenos fantasma (uno completado con series "Ok" 0 kg para poder salir, otro aún en curso) y una serie de calves no registrada en un entreno ya completado. ADR-0001 prohíbe `UPDATE`/`DELETE` sobre eventos: la corrección debe ser ella misma eventos. Hay que decidir la forma de esos eventos, cómo los absorben las proyecciones (los acumuladores no saben restar), y qué pasa con la API pública (el hub ya contó al fantasma completado — y ADR-0009 dice que lo publicado no se despublica).

## Opciones consideradas

### Forma de los eventos

**A. Compensatorios explícitos y distintos (elegida).** `gym.workout_discarded` v1 (con `wasCompleted`: el agregado sabe si el descarte revierte algo ya anunciado) y `gym.set_logged_late` v1 (misma forma que `set_logged`). Comandos `DiscardWorkout` y `AddMissedSet` con invariantes propias. Pro: el log cuenta la verdad completa — pasó X, se corrigió con Y — y cada projector recibe semántica inequívoca (una serie tardía se bucketiza por la semana del workout, no por la del envelope). Con: dos tipos de evento más que mantener para siempre.

**B. Reutilizar `set_logged` relajando "no series tras completar" desde un comando de corrección.** Pro: cero tipos nuevos. Con: el log miente por omisión (corrección indistinguible de bug de UI), la invariante pierde su valor de red de seguridad, y el volumen de la serie tardía caería en la semana de la corrección, no la del entreno.

**C. `workout_corrected` genérico con payload polimórfico** (`kind: discard | add_set`). Pro: un solo tipo. Con: es un switch disfrazado de evento; versionar un payload polimórfico es peor que versionar dos eventos chicos.

### Read model ante el descarte

Restricción dura: al llegar `workout_discarded`, restar el volumen exige saber cuánto aportó el workout y a qué semanas — el evento no lo sabe, y el agregado no puede calcular los buckets (los `occurredAt` son metadata del envelope que `apply()` no ve, ADR-0003). El "fat event" no alcanza.

**A. Tabla granular + agregación en consulta (elegida).** `gym_sets` (una fila por serie, con su semana) reemplaza al acumulador `gym_weekly_volume`; el volumen semanal pasa a ser `GROUP BY` en la consulta. Descartar = `DELETE WHERE workout_id`. Pro: la resta desaparece como categoría de problema, y la tabla de series es la base que ya piden el detalle de entreno, los PRs y las tendencias (mismo hito). Con: agregar en tiempo de consulta (irrelevante a esta escala) y reescribir un projector que funcionaba.

**B. Acumulador + tabla auxiliar de contribuciones** workout→semana para poder restar. Pro: toca menos. Con: dos tablas que mantener coherentes, y la tabla de series habrá que crearla igual en dos fases.

### Frontera pública

**A. Integration event compensatorio (elegida).** `gym.workout_discarded` v1 como contrato público, publicado por una policy **solo si el workout estaba completado** (un descarte en curso nunca fue anunciado: no hay nada que compensar). El hub reestructura su read model al mismo patrón granular (`hub_workouts`: fila por workout con su semana; conteo por `GROUP BY`) porque su acumulador tampoco sabe restar — y el contrato queda mínimo (`workout_id`, `discarded_at`): cada consumidor guarda el estado que necesita para compensar. Pro: la pantalla principal dice la verdad; el patrón compensatorio se replica donde más importa, la API pública. Con: toca gym, hub y el doc del contrato.

**B. Diferir.** El hub queda contando un entreno inexistente desde el día uno del MVP. Descartada: el problema reaparece igual, sin datos frescos para estrenarlo.

## Decisión

Compensatorios explícitos (A) + read models granulares con agregación en consulta (A) + integration event compensatorio (A). **`set_corrected` (corregir peso/reps de una serie) se difiere** a la fase de UX de registro: exige identidad de serie, que también necesitan los dropsets — se decide una sola vez allí. Costo aceptado: un typo durante la prueba queda sin corrección hasta esa fase.

Pieza habilitante: los engines ganan `catchUp()` (despacho con guarda de checkpoint, sin reset) y la app lo corre al arrancar. Un projector nuevo o renombrado nace con checkpoint 0 y se backfillea solo desde el log correspondiente — así `gym_sets` y `hub_workouts` se poblarán con los eventos ya persistidos en el A71 sin migración manual. Los projectors reestructurados **cambian de nombre** (`gym.weekly_volume` → `gym.workout_sets`; `hub.weekly_workouts` → `hub.workouts`) precisamente para nacer con checkpoint fresco.

## Consecuencias

- Eventos persistidos nuevos: `gym.workout_discarded` v1 (domain), `gym.set_logged_late` v1 (domain), `gym.workout_discarded` v1 (integration, en `docs/integration-events.md`).
- El agregado `Workout` gana el estado terminal `discarded`: nada se le puede hacer a un workout descartado; descartar vale desde en-curso o completado, una sola vez. `AddMissedSet` solo sobre completados (en curso se usa `LogSet`).
- Los workouts descartados desaparecen de los read models (DELETE); los eventos los recuerdan para siempre. Una vista "papelera" futura sería una proyección nueva, no un cambio de estos.
- `gym_weekly_volume` y `hub_weekly_workouts` se eliminan (DROP en el create del schema: las tablas de lectura son desechables por contrato). Sus filas de checkpoint quedan huérfanas — inocuas.
- La semana de una serie tardía es la semana del workout (derivada de la primera serie en `gym_sets` — siempre existe: no se completa sin series). Primer caso real donde el tiempo de negocio difiere del de persistencia, como anticipó ADR-0003.
- La prueba ácida cambia de tablas pero no de contrato; el test contra los datos reales del A71 compara los agregados equivalentes (volumen semanal y conteo por semana derivados de las tablas granulares vs. los capturados en vivo).
- Riesgo aceptado: el catch-up del arranque lee el log completo en cada boot. A volumen local-first es barato; si duele, se optimiza con un head-check sin cambiar contratos.
