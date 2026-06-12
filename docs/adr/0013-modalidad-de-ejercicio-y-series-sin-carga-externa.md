# ADR-0013: modalidad de ejercicio en el catálogo y series sin carga externa

- **Fecha:** 2026-06-11
- **Estado:** aceptada

## Contexto

Los ejercicios de abdomen (y a futuro fondos, dominadas, planchas) son comúnmente de peso corporal: no hay carga externa que registrar. Hoy `SetLogged.weightKg` es **requerido** y todas las estadísticas derivan de `peso × reps`, así que una serie de crunches no tiene representación honesta: o se inventa un peso o no se registra. El caso real que lo destapó: el único "abdominal" registrado hasta hoy ("Abdominal curl", 70→40 kg) es de máquina — es decir, la modalidad es **por ejercicio**, no por grupo muscular. Restricciones: weak schema desde el primer evento (los ~34 eventos del A71 no se tocan), datos crudos sin inventar (DESIGN.md `[DATA-003]`: nada de ceros donde el dato no existe), y la consecuencia de ADR-0011 de que `Workout` no valida contra el catálogo.

## Opciones consideradas

### Representación de la serie sin carga

**A. `weightKg` opcional: `null` = solo peso corporal, valor = lastre añadido (elegida).** Es la dirección segura del weak schema: los eventos persistidos lo tienen, los lectores nuevos toleran su ausencia. El lastre (disco en el pecho, chaleco) conserva la progresión de carga también en bodyweight. Pro: el dato es honesto — no medimos la carga, no la inventamos. Con: todo el read-side y la UI deben tolerar el null, y el volumen kg pasa a significar "carga externa" (una serie corporal sin lastre aporta 0 a ese agregado).

**B. Convención `weightKg = 0`.** Pro: cero cambios de esquema, SQL trivial. Con: "tu PR de crunch: 0 kg"; el 0 fantasma contamina promedios y PRs y es exactamente el anti-patrón de `[DATA-003]`.

**C. Estimar % del peso corporal** (multiplicar reps por una fracción del peso del usuario). Pro: volumen "completo". Con: inventa datos (contra el principio de datos crudos), exige un concepto de perfil de usuario que no existe, y la fracción por ejercicio es pseudociencia de tabla de internet. Descartada de plano.

### Dónde vive la modalidad

**A. En el catálogo: `exercise_added` gana `modality` opcional (elegida).** `weighted` (default) | `bodyweight`, string estable en el payload, weak schema — los ejercicios ya persistidos quedan `weighted`, que es correcto para los 7 existentes. Las estadísticas y la UI resuelven el tratamiento por ejercicio. Compensatorio `exercise_modality_corrected` (espejo del de grupo muscular) para altas equivocadas.

**B. Por serie (flag en `set_logged`).** Pro: flexibilidad serie a serie. Con: redundante (la modalidad es una propiedad del ejercicio), infla cada evento y deja la puerta a inconsistencias dentro del mismo ejercicio.

### Quién exige "weighted ⇒ peso obligatorio"

**A. La UI valida; el dominio acepta peso null en cualquier serie (elegida).** Consistente con el precedente de ADR-0011 ("la UI selecciona del catálogo, el id es válido por construcción"): `Workout` sigue sin conocer el catálogo. Riesgo aceptado: un bug de UI podría colar una serie weighted sin peso — defecto cosmético, corregible con `set_corrected`.

**B. El handler de `LogSet` rehidrata `ExerciseCatalog` y rechaza.** Pro: invariante dura en el write-side sin romper CQRS (rehidrata de eventos, no lee proyecciones). Con: acopla los dos agregados del módulo en cada registro de serie — el camino más caliente de la app — para proteger contra un caso que la UI ya hace imposible por construcción.

### Estadística entre modalidades

- **Por ejercicio:** weighted → progresión de carga (PR de peso); bodyweight → progresión de reps (PR = máx reps, tendencia = reps por sesión) y de lastre si lo hay.
- **Por grupo muscular:** la métrica comparable entre modalidades es **series por grupo por semana** (la estándar de la literatura de hipertrofia, precisamente porque sobrevive a la mezcla). El "volumen kg" agregado pasa a leerse como *carga externa total* — las series corporales aportan solo su lastre.

## Decisión

`weightKg` opcional con semántica null = corporal / valor = lastre (A) + modalidad en el catálogo con default weighted por weak schema (A) + validación por modalidad en la UI (A). Eventos: `gym.exercise_added` v1 gana `modality` opcional; nuevo `gym.exercise_modality_corrected` v1; `set_logged` / `set_logged_late` / `set_removed` / `set_corrected` siguen v1 con `weightKg` (y `oldWeightKg`) opcionales. Comandos: `AddExercise.modality`, `CorrectExerciseModality`; `LogSet` / `AddMissedSet` / `CorrectSet` con peso opcional.

Read-side: `gym_exercises` gana columna `modality` (ALTER TABLE idempotente — agregar columna con default no exige rebuild); `gym_sets.weight_kg` pasa a nullable, lo que en SQLite exige recrear la tabla: como las tablas de lectura son **desechables por contrato**, el create detecta el esquema viejo por pragma, tira la tabla y el projector renace con otro nombre (`gym.workout_sets` → `gym.workout_sets_v2`, checkpoint 0) para que el catch-up del arranque la reconstruya — la mecánica de ADR-0010.

En pantalla: serie corporal `× 12`, con lastre `+5 kg × 12` (el `+` lo habilita la modalidad, resuelta por join al catálogo); el campo de peso en Entrenar se vuelve "Lastre (kg) · opcional" cuando el ejercicio es bodyweight.

## Consecuencias

- El primer evento del módulo cambia de forma (campo que deja de ser requerido): estreno real del weak schema en la dirección "lector tolera ausencia". Ningún evento persistido se reescribe ni se versiona.
- "Volumen" en historial y contadores significa desde ahora **carga externa**: honesto pero parcial para bodyweight. La estadística de progresión del hito debe tratar las dos modalidades por separado (PR de peso vs PR de reps) y usar series/grupo/semana como métrica transversal.
- La UI es la única guardia de "weighted necesita peso": un dato colado es cosmético y compensable, no corrupción. Si alguna vez duele, la opción B (handler rehidrata catálogo) sigue disponible sin tocar eventos.
- La prueba ácida cubre el camino nuevo igual que siempre: reset + replay con eventos con y sin `weightKg` debe reproducir el estado exacto.
- Queda prohibido registrar `0` como sustituto de "sin carga": el 0 es una carga medida (barra vacía no existe, pero un lastre de 0 tampoco se registra).
