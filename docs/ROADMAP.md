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

## Hito 1 — Walking skeleton (Fases 0→4 en vertical)

Una sola acción de punta a punta: **loggear un workout y ver el historial con una estadística derivada**. Valida toda la arquitectura con el mínimo de código.

- [ ] **Fase 0 — Core:** cerrar preguntas abiertas del README de `core` (generación de eventId/occurredAt, wiring de proyecciones) e implementar event store en Drift (append atómico + proyecciones síncronas en la misma transacción, concurrencia optimista, readAll para replay)
- [ ] **Fase 1 — Gym write-side:** agregado Workout + comandos LogWorkout, con tests de invariantes
- [ ] **Fase 2 — Read-side:** proyección de historial + 1 estadística derivada (p. ej. volumen semanal), test de replay (`reset()` + readAll ≡ estado idéntico)
- [ ] **Fase 3 — UI:** `flutter create` de la app shell, 2 pantallas (loggear / historial) con Riverpod + StreamProvider sobre Drift
- [ ] **Fase 4 — Frontera hub↔módulo:** primer integration event (`gym.workout_completed` v1) publicado por gym y consumido por un hub esqueleto que muestre "entrenos esta semana: N"

**Gate de salida:** la prueba ácida pasa (borrar proyecciones + replay = mismo estado) y el flujo completo corre en el A71 físico.

## Hito 2 — Gym usable a diario (= MVP)

Del esqueleto a herramienta real. Alcance orientativo, se refina al cerrar Hito 1:

- [ ] Catálogo de ejercicios propio (crear/editar ejercicios)
- [ ] Registro cómodo de series/reps/peso durante el entreno (UX de gimnasio: rápido, una mano)
- [ ] Corrección de errores vía eventos compensatorios (WorkoutCorrected/Discarded — sin UPDATE)
- [ ] Estadísticas de progresión: PRs, volumen por grupo muscular, tendencia por ejercicio
- [ ] Empezar periodo de prueba de 2 semanas de uso real

## Hito 3 — Post-MVP: validar la modularidad

- [ ] Módulo **days** (calificar el día): trivial en dominio, su valor es probar que el checklist de "agregar un módulo" funciona sin tocar gym ni core
- [ ] Primera correlación real en el hub (ánimo vs. días de entreno)
- [ ] Retro de arquitectura: ¿qué dolió? → ADRs correctivos

## Backlog lejano (sin orden ni compromiso)

Journaling · módulo música · sync multi-dispositivo · versión web · snapshots (solo si algún stream duele).

## Riesgos vigilados

- **Sobre-ingeniería antes de uso real** → mitigación: gate de Hito 2 es uso, no features.
- **Versionado de eventos mal manejado al iterar gym** → mitigación: weak schema desde el primer evento; upcaster solo cuando duela.
- **Pérdida de rumbo entre sesiones** → mitigación: este roadmap + ADRs; toda sesión de diseño termina actualizándolos.
