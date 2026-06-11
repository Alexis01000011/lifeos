# Roadmap — hacia el MVP

> **Definición de MVP (2026-06-09):** la app gym es usable a diario en el A71 — registro mis entrenos reales y veo mi progreso sin abrir el IDE. No es una demo de arquitectura: es una app que uso.
>
> **Criterio de terminado del MVP:** dos semanas seguidas registrando todos mis entrenos reales solo desde la app, sin necesitar hotfixes.

Cada hito termina con su casilla marcada y, si hubo decisiones, su ADR. Este documento se actualiza al cerrar cada hito — un roadmap desactualizado es peor que no tener roadmap.

## Hito 0 — Gobernanza ✅ (2026-06-09)

- [x] Decisión persistencia: ES puro + proyecciones síncronas (ADR-0001)
- [x] Decisión UI/DI: Riverpod (ADR-0002)
- [x] Borrador de abstracciones core (`packages/core`)
- [x] Repo, visión, roadmap, protocolo ADR
- [x] Conectar repo a GitHub (manual, Alexis)

## Hito 1 — Walking skeleton (Fases 0→4 en vertical) ✅ (2026-06-10)

Una sola acción de punta a punta: **loggear un workout y ver el historial con una estadística derivada**. Valida toda la arquitectura con el mínimo de código.

- [x] **Fase 0a — Decisiones de core cerradas** (2026-06-10): eventId/occurredAt en el append (ADR-0003), ProjectionEngine aparte (ADR-0004), DomainException con string hasta el 2º módulo (ADR-0005), snapshots e integration events confirmados diferidos
- [x] **Fase 0b — Core implementado** (2026-06-10): `ProjectionEngine` y `DefaultEventTypeRegistry` en core (10 tests); paquete `core_drift` (ADR-0006) con event store en Drift — append atómico + proyecciones síncronas en la misma transacción zone-based, concurrencia optimista, readAll para replay (11 tests de integración, incl. rollback por projector fallido y mini prueba ácida)
- [x] **Fase 1 — Gym write-side** (2026-06-10): paquete `gym` (depende solo de core) con agregado `Workout` como ciclo de vida (ADR-0007) y comandos `StartWorkout`/`LogSet`/`CompleteWorkout`; 16 tests de invariantes, serialización y flujo de handlers sobre `InMemoryEventStore` (nuevo en `core/testing`)
- [x] **Fase 2 — Read-side** (2026-06-10): proyecciones de historial y volumen semanal con SQL crudo + notifyUpdates (ADR-0008), API de consulta `GymReadModels`, y la prueba ácida oficial pasando contra tablas reales (reset + replay ≡ estado idéntico); reloj inyectable en `DriftEventStore` y `TestDatabase` compartida en `core_drift/testing`
- [x] **Fase 3 — UI** (2026-06-10): app shell en `app/` (Flutter, targets android+windows) con composition root en Riverpod 3 — `databaseProvider` overrideado en main(), todo lo demás derivado; helper `watchQuery` (tableUpdates → re-query) en core_drift cerrando el pendiente de ADR-0008; pantallas Entrenar (workout en curso desde proyección, despacho de comandos, DomainException → SnackBar) e Historial (volumen semanal + entrenos); 3 tests de widget corren el esqueleto entero por la UI real contra SQLite en memoria
- [x] **Fase 4 — Frontera hub↔módulo** (2026-06-10): integration events con log persistido tipo outbox (ADR-0009) — `gym.workout_completed` v1 documentado en `docs/integration-events.md`, publicado por una policy de gym (idempotente por causation id, "lo publicado no se despublica") y consumido por el paquete nuevo `hub` (depende solo de core, con su propia prueba ácida sobre el log de integración); pantalla Inicio con "entrenos esta semana: N" clickeable hacia el módulo — el embrión de la pantalla principal

**Gate de salida — cumplido (2026-06-10):** la prueba ácida pasa ✅ y el flujo completo corrió en el A71 físico con un entreno real (leg day: 23 series, 11,440 kg de volumen). La base se extrajo del dispositivo por adb y la prueba ácida se corrió **contra los datos reales** (`app/test/acid_real_device_test.dart`): reset + replay de los 30 eventos reproduce el estado en vivo tabla por tabla, hub incluido. La arquitectura completa quedó validada con uso de verdad, no con fixtures.

## Hito 2 — Gym usable a diario (= MVP)

Del esqueleto a herramienta real. Alcance refinado con el feedback del primer uso real en el gimnasio (2026-06-10):

- [ ] Catálogo de ejercicios propio (crear/editar ejercicios)
- [ ] Registro cómodo de series/reps/peso durante el entreno (UX de gimnasio: rápido, una mano)
  - Mini-registro de las últimas ~3 series en pantalla ("¿en qué serie voy?")
  - Peso en lb convertible a kg (las mancuernas del gym mezclan unidades; datos normalizados en kg)
  - Representar dropsets (semántica real observada el primer día: 70 kg → ~15 s quitando discos → 40 kg; hoy el workaround es series consecutivas con descanso corto)
  - Registro en diferido de series olvidadas (pasó el primer día: "olvidé registrar la pasada, registro 2 ahora" — quedaron 4 s aparte con el mismo descanso)
  - Corregir una serie mal registrada (`set_corrected`): exige identidad de serie — se decide acá, junto con los dropsets, que también la necesitan (diferido en ADR-0010)
- [x] Corrección de errores vía eventos compensatorios (2026-06-10, ADR-0010: `workout_discarded` + `set_logged_late`, integration event compensatorio hacia el hub, read models granulares con GROUP BY, catch-up de proyecciones al arrancar)
  - Cancelar/descartar un entreno empezado por error ✅ (botón en Entrenar y menú en Historial)
  - Agregar serie olvidada a un entreno completado ✅ (menú en Historial; se bucketiza en la semana del entreno)
  - **Pendiente de aplicar en el A71**: el backlog real del 2026-06-10 — descartar los 2 entrenos fantasma (db99e5a0 completado con series "Ok"; bf0d7bfd aún en curso) y agregar la serie de calves 40 kg. Al instalar la versión nueva, el catch-up backfillea `gym_sets`/`hub_workouts` solo; las correcciones se hacen desde la UI y después conviene extraer la base (build debug) y correr la prueba ácida real
- [ ] Semántica del descanso: hoy es `restBeforeSeconds` (descanso ANTES de la serie); revisar qué pasa con la primera y la última serie del entreno y dejarlo explícito en la UI
- [ ] Detalle de un entreno pasado: tocar un workout en Historial y ver sus series
- [ ] Estadísticas de progresión: PRs, volumen por grupo muscular, tendencia por ejercicio
- [ ] Empezar periodo de prueba de 2 semanas de uso real

## Hito 3 — Post-MVP: validar la modularidad

- [ ] Módulo **days** (calificar el día): trivial en dominio, su valor es probar que el checklist de "agregar un módulo" funciona sin tocar gym ni core
- [ ] Migrar `DomainException` a errores tipados por módulo (trigger pactado en ADR-0005; lo reemplaza un ADR nuevo)
- [ ] Primera correlación real en el hub (ánimo vs. días de entreno)
- [ ] Retro de arquitectura: ¿qué dolió? → ADRs correctivos

## Backlog lejano (sin orden ni compromiso)

Journaling · módulo música · sync multi-dispositivo · versión web · snapshots (solo si algún stream duele).

## Riesgos vigilados

- **Sobre-ingeniería antes de uso real** → mitigación: gate de Hito 2 es uso, no features.
- **Versionado de eventos mal manejado al iterar gym** → mitigación: weak schema desde el primer evento; upcaster solo cuando duela.
- **Pérdida de rumbo entre sesiones** → mitigación: este roadmap + ADRs; toda sesión de diseño termina actualizándolos.
