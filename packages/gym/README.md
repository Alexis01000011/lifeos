# gym — bounded context de entrenamientos

Primer módulo de lifeos. Depende **solo** de `core` (regla de fronteras: si esto cambia, la arquitectura falló).

## Write-side (Fase 1)

- **Agregado `Workout`**: UN entrenamiento (agregados chicos, ADR-0001). Ciclo de vida: `start()` → `logSet()`×n → `complete()` (ADR-0007).
- **Domain events** (privados del módulo): `gym.workout_started` v1 · `gym.set_logged` v1 (ejercicio texto libre, kg, reps, `restBeforeSeconds` opcional) · `gym.workout_completed` v1.
- **Comandos**: `StartWorkout`, `LogSet`, `CompleteWorkout` — handlers que solo orquestan; las invariantes viven en el agregado:
  - no iniciar dos veces; no operar sobre workouts inexistentes o no iniciados
  - no agregar series a un workout completado
  - serie: ejercicio no vacío, reps ≥ 1, peso ≥ 0 (peso corporal = 0), descanso ≥ 0
  - no completar dos veces ni sin series registradas
- `registerGymEvents(registry)`: la app shell lo llama al componer el registry global.

## Read-side (Fase 2)

- **Tablas propias** (ADR-0008, SQL crudo sobre la database compuesta): `gym_workout_history` (una fila por workout: inicio, fin, series, volumen) y `gym_weekly_volume` (volumen kg×reps por semana ISO, bucketing UTC — simplificación a revisar en Hito 2).
- **Projectors**: `WorkoutHistoryProjector` y `WeeklyVolumeProjector` — acumuladores no idempotentes por sí solos; la guarda de checkpoint del `ProjectionEngine` garantiza "cada envelope a lo sumo una vez".
- **`GymReadModels`**: API de consulta con DTOs (`WorkoutSummary`, `WeeklyVolume`) que la UI envolverá en providers.
- La **prueba ácida** corre contra estas tablas en `test/projections_test.dart`.

## Pendiente

- **Fase 3**: pantallas (loggear / historial) y providers; helper de reactividad tableUpdates → re-query.
- **Fase 4**: integration event `gym.workout_completed` v1 hacia el hub (contrato público, distinto del domain event homónimo).
- **Hito 2**: catálogo de ejercicios, eventos compensatorios (corrección/descarte), registro en diferido.
