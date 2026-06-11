# hub — agregación entre módulos

El tercer vértice del grafo de dependencias (VISION Regla 1): `hub` → `core`, nada más. Será la pantalla principal de la app: estadísticas de los módulos y punto de entrada hacia ellos.

## Regla de oro (Regla 3)

El hub **solo conoce integration events**. No importa módulos, no lee sus tablas, no conoce sus agregados. Consume contratos JSON documentados en `docs/integration-events.md` con sus propias clases consumidoras (`GymWorkoutCompleted`, `GymWorkoutDiscarded`) — schema-first, como entre servicios.

## Estado

- `registerHubIntegrationEvents(registry)`: deserializadores de los contratos consumidos.
- `HubWorkoutsProjector` (`IntegrationProjector`): una fila por workout anunciado en `hub_workouts` (ADR-0010); el conteo semanal es GROUP BY en la consulta. Bucketiza con el `completed_at` del payload — el hub decide con el contrato, no con metadata de transporte. El compensatorio `gym.workout_discarded` es un DELETE; un descarte de workout desconocido se ignora sin error.
- `HubReadModels`: consulta para la pantalla "Inicio" ("entrenos esta semana: N").
- Su prueba ácida propia: reset + replay del **log de integración** ≡ estado idéntico.

## Futuro

Correlaciones reales (ánimo vs. entrenos, Hito 3) cuando exista un segundo módulo publicando.
