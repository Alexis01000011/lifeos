# gym — bounded context de entrenamientos

Primer módulo de lifeos. Depende **solo** de `core` (regla de fronteras: si esto cambia, la arquitectura falló).

## Write-side (Fase 1, catálogo en Hito 2)

- **Agregado `Workout`**: UN entrenamiento (agregados chicos, ADR-0001). Ciclo de vida: `start()` → `logSet()`×n → `complete()` (ADR-0007), más los compensatorios `discard()` y `addMissedSet()` (ADR-0010).
- **Agregado `ExerciseCatalog`** (ADR-0011): singleton (`gym.exercise_catalog`/`catalog`) — la unicidad de nombres es set-validation y solo puede ser invariante dentro del agregado que contiene el set completo. Cubre nombres actuales, históricos (pre-rename) y legacy, normalizados (trim + case-insensitive); renombrar nunca libera el nombre viejo.
- **Domain events** (privados del módulo): `gym.workout_started` v1 · `gym.set_logged` v1 (nombre denormalizado, `exerciseId` opcional por weak schema, kg, reps, `restBeforeSeconds` opcional) · `gym.workout_completed` v1 · `gym.workout_discarded` v1 (compensatorio, con `wasCompleted`) · `gym.set_logged_late` v1 (compensatorio, misma forma que `set_logged`) · `gym.exercise_added` v1 (con `legacyNames`) · `gym.exercise_renamed` v1.
- **Comandos**: `StartWorkout`, `LogSet`, `CompleteWorkout`, `DiscardWorkout`, `AddMissedSet`, `AddExercise` (load-or-create del singleton), `RenameExercise` — handlers que solo orquestan; las invariantes viven en el agregado:
  - no iniciar dos veces; no operar sobre workouts inexistentes o no iniciados
  - no agregar series a un workout completado (la serie olvidada va por `AddMissedSet`, que solo vale sobre completados)
  - serie: ejercicio no vacío, reps ≥ 1, peso ≥ 0 (peso corporal = 0), descanso ≥ 0; el `exerciseId` NO se valida contra el catálogo (invariante entre agregados: la UI selecciona, llega válido por construcción)
  - no completar dos veces ni sin series registradas
  - el descarte es terminal: vale en curso o completado, una sola vez, y después nada
  - catálogo: ningún nombre (actual, histórico o legacy) puede pertenecer a dos ejercicios
- `registerGymEvents(registry)`: la app shell lo llama al componer el registry global.

## Read-side (Fase 2, reestructurado en Hito 2)

- **Tablas propias** (ADR-0008, SQL crudo sobre la database compuesta): `gym_workout_history` (una fila por workout: inicio, fin, series, volumen), `gym_sets` (una fila por serie con su semana ISO, ADR-0010 — el volumen semanal es GROUP BY en la consulta; bucketing UTC, simplificación a revisar junto al resto del Hito 2), `gym_exercises` y `gym_exercise_names` (ADR-0011: catálogo + mapa nombre normalizado → ejercicio con que se resuelven las series viejas a texto libre). `gym_sets` aún no lleva `exercise_id`: se agrega cuando la primera estadística lo consuma (mecánica de rename + catch-up, ADR-0010).
- **Projectors**: `WorkoutHistoryProjector`, `WorkoutSetsProjector` y `ExerciseCatalogProjector` — no idempotentes por sí solos; la guarda de checkpoint del `ProjectionEngine` garantiza "cada envelope a lo sumo una vez". El descarte es DELETE en historia y series; la serie tardía se bucketiza por la semana del workout (heredada de su primera serie), no por la de la corrección.
- **`GymReadModels`**: API de consulta con DTOs (`WorkoutSummary`, `WeeklyVolume`, `ExerciseSummary`) que la UI envuelve en providers.
- La **prueba ácida** corre contra estas tablas en `test/projections_test.dart`, historia compensatoria incluida.

## UI (Fase 3)

- Las pantallas y providers viven en la app shell (`app/`), no acá: gym no depende de Flutter ni de Riverpod. La UI consume `GymReadModels` vía `watchQuery` (core_drift) y despacha los comandos de este paquete.

## Lado público (Fase 4)

- `PublishWorkoutCompletedPolicy` (ADR-0009): traduce el domain event `gym.workout_completed` al integration event homónimo — contrato distinto, log distinto, documentado en `docs/integration-events.md`. Idempotente por causation id; su `reset()` es no-op: lo publicado no se despublica.
- `PublishWorkoutDiscardedPolicy` (ADR-0010): publica el compensatorio `gym.workout_discarded` **solo si el workout estaba completado** — lo nunca anunciado no se compensa.

## Pendiente

- **Hito 2**: UX de registro (dropsets, lb→kg — incluye `set_corrected`, diferido en ADR-0010 hasta resolver identidad de serie junto a los dropsets), detalle de entreno, estadísticas de progresión (primera consumidora del `exercise_id` en `gym_sets` y del mapa de nombres, ADR-0011).
