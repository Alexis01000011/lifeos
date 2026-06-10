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

## Pendiente

- **Fase 2**: proyección de historial + volumen semanal, test de la prueba ácida con tablas reales.
- **Fase 4**: integration event `gym.workout_completed` v1 hacia el hub (contrato público, distinto del domain event homónimo).
- **Hito 2**: catálogo de ejercicios, eventos compensatorios (corrección/descarte), registro en diferido.
