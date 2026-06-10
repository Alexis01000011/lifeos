# hub — agregación entre módulos

El tercer vértice del grafo de dependencias (VISION Regla 1): `hub` → `core`, nada más. Será la pantalla principal de la app: estadísticas de los módulos y punto de entrada hacia ellos.

## Regla de oro (Regla 3)

El hub **solo conoce integration events**. No importa módulos, no lee sus tablas, no conoce sus agregados. Consume contratos JSON documentados en `docs/integration-events.md` con sus propias clases consumidoras (`GymWorkoutCompleted`) — schema-first, como entre servicios.

## Fase 4 (esqueleto)

- `registerHubIntegrationEvents(registry)`: deserializadores de los contratos consumidos.
- `WeeklyWorkoutCountProjector` (`IntegrationProjector`): cuenta entrenos por semana ISO sobre `hub_weekly_workouts`. Bucketiza con el `completed_at` del payload — el hub decide con el contrato, no con metadata de transporte.
- `HubReadModels`: consulta para la pantalla "Inicio" ("entrenos esta semana: N").
- Su prueba ácida propia: reset + replay del **log de integración** ≡ estado idéntico.

## Futuro

Correlaciones reales (ánimo vs. entrenos, Hito 3) cuando exista un segundo módulo publicando.
