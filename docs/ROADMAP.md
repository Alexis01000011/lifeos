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

- [x] Catálogo de ejercicios propio (2026-06-10, ADR-0011: agregado único `ExerciseCatalog` — la unicidad de nombres es set-validation y vive en el agregado; `exerciseId` opcional en las series por weak schema; vinculación de nombres históricos para que las 27 series viejas a texto libre entren a las estadísticas; variantes = entradas separadas; pantalla Ejercicios + picker con alta al vuelo en Entrenar e Historial)
  - Build con catálogo instalado en el A71 (2026-06-11, datos verificados intactos: 34 eventos). **Pendiente de cargar**: el inventario real (`docs/gym_inventario.md`, ~30 ejercicios) desde la pantalla Ejercicios — o al vuelo durante los entrenos. Los 7 nombres ya usados (Calves, Leg press, Leg extension, Pendulum squat, Sumo squat, Abdominal curl, Smith Machine FFE Split Squat) vinculan solos si el ejercicio se crea con el mismo nombre; si se crea con otro, anotarlos como nombre histórico en el alta
- [ ] Registro cómodo de series/reps/peso durante el entreno (UX de gimnasio: rápido, una mano)
  - Mini-registro de las últimas ~3 series en pantalla ("¿en qué serie voy?")
  - **Pre-llenar el último peso/reps usados** al seleccionar un ejercicio — se lee la última serie registrada de ese ejercicio desde la proyección; si el usuario quiere subir, ajusta, si no, confirma directamente
  - **Swipe para eliminar la última serie del entreno en curso** — gesto lateral sobre la mini-lista de últimas ~3 series; emite el compensatorio de ADR-0010; aplica solo a la última serie (no correcciones arbitrarias en medio del historial)
  - Peso en lb convertible a kg (las mancuernas del gym mezclan unidades; datos normalizados en kg)
  - Representar dropsets (semántica real observada el primer día: 70 kg → ~15 s quitando discos → 40 kg; hoy el workaround es series consecutivas con descanso corto)
  - Registro en diferido de series olvidadas (pasó el primer día: "olvidé registrar la pasada, registro 2 ahora" — quedaron 4 s aparte con el mismo descanso)
  - Corregir una serie mal registrada (`set_corrected`): exige identidad de serie — se decide acá, junto con los dropsets, que también la necesitan (diferido en ADR-0010)
- [ ] Mejoras de UX en el catálogo y el picker de ejercicios
  - **Picker con doble filtro automático** (pantalla Entrenar): si el query coincide con un nombre de grupo muscular conocido → filtra por grupo; si no → filtra por nombre de ejercicio. Sin switch explícito. Buscar "Pecho" muestra todos los ejercicios de pecho; buscar "Press plano" filtra por nombre. Edge case documentado: si un nombre de ejercicio coincide con un nombre de grupo, el grupo muscular gana.
  - **Sección "Frecuentes" al tope del picker**: los ejercicios ordenados por frecuencia de uso (conteo de `set_logged` por `exerciseId` en la proyección) aparecen primero, antes de los grupos alfabéticos. Fallback si no convence en uso real: la sección "Frecuentes" se vuelve colapsable y se puede dejar colapsada permanentemente — el resto del picker (grupos alfabéticos) sigue siendo 100% funcional.
  - **Grupos musculares colapsables en pantalla Ejercicios**: cada sección de grupo (p. ej. "Pecho", "Piernas") tiene un header colapsable; al abrir la pantalla todos están expandidos, pero se pueden plegar para navegar entre grupos sin deslizar toda la lista
- [x] Corrección de errores vía eventos compensatorios (2026-06-10, ADR-0010: `workout_discarded` + `set_logged_late`, integration event compensatorio hacia el hub, read models granulares con GROUP BY, catch-up de proyecciones al arrancar)
  - Cancelar/descartar un entreno empezado por error ✅ (botón en Entrenar y menú en Historial)
  - Agregar serie olvidada a un entreno completado ✅ (menú en Historial; se bucketiza en la semana del entreno)
  - **Aplicado en el A71** ✅ (2026-06-10): los 2 fantasmas descartados desde la UI y la serie olvidada de calves registrada (resultó dropset: 70 kg ×10 → 40 kg ×10 con 15 s, el workaround vigente). El catch-up del arranque backfilleó las tablas granulares solo, y la prueba ácida real pasó contra las tres capturas de `tmp/` (generación vieja, base post-wipe y corregida). Incidente del día: un `flutter run` reinstaló la app y **borró los datos del dispositivo**; se restauró desde el backup extraído por adb sin pérdida
- [ ] Semántica del descanso: hoy es `restBeforeSeconds` (descanso ANTES de la serie); revisar qué pasa con la primera y la última serie del entreno y dejarlo explícito en la UI
- [x] Detalle de un entreno pasado: tocar un workout en Historial y ver sus series (ya implementado en el walking skeleton — pantalla `WorkoutDetailScreen` con series agrupadas por separador, chip "tardía", y navegación desde `HistoryScreen`)
- [ ] Estadísticas de progresión: PRs, volumen por grupo muscular, tendencia por ejercicio
- [ ] Empezar periodo de prueba de 2 semanas de uso real

## Hito 3 — Módulo `days` + validar la modularidad

> **Diseño completo:** `docs/design/modulos-post-mvp.md` (sesión 2026-06-11). El plan de telemetría es `gym → days → sleep → affect`, basado en la investigación de evidencia científica. Cada módulo se empieza solo cuando el anterior está en **uso diario real** (anti-meta: funcionalidad usada > construida).

Primer módulo nuevo tras el MVP. Alcance v1: solo `DayRated` (nota 0–10 + tags); los episodios DRM se difieren. Su valor doble: dar la primera serie temporal correlacionable **y** probar que el checklist de "agregar un módulo" funciona sin tocar gym ni core.

- [ ] Paquete `packages/days` (depende solo de core): agregado `Day`, eventos `DayRated` / `DayRatingAmended` (privados)
- [ ] Integration event `days.day_rated` v1 documentado en `docs/integration-events.md`
- [ ] Read-side: serie temporal de la nota + net affect por tag (SQL crudo, estilo ADR-0008)
- [ ] Pantallas Calificar hoy / Historial de días + tarjeta en el hub
- [ ] Migrar `DomainException` a errores tipados por módulo (trigger pactado en ADR-0005; `days` ES el 2º módulo → lo dispara; lo reemplaza un ADR nuevo)
- [ ] **Primera correlación real en el hub: ánimo (days) vs. días de entreno (gym)** — exige el motor con normalización within-person desde el inicio (ver Hito 5)
- [ ] Decisiones abiertas a cerrar con ADR al implementar: D-1 (`Day` re-calificable), D-2 (compensatorios al hub), D-3 (set de tags)
- [ ] Gate de salida: `days` en uso diario real + checklist de módulo cumplido sin editar otro módulo
- [ ] Retro de arquitectura: ¿qué dolió al agregar el 2º módulo? → ADRs correctivos

## Hito 4 — Módulo `sleep` (diario de sueño) + correlación estrella

Trae la correlación de mayor relación evidencia/valor de toda la app. Se empieza tras `days` en uso real. **Captura híbrida (2026-06-11):** Samsung Health → Health Connect ya da los tiempos; lo manual se reduce a calidad subjetiva en 1 toque (la variable de la correlación estrella se conserva).

- [ ] Paquete `packages/sleep`: agregado `SleepEntry`; eventos `SleepSessionImported` (HC, idempotente por id externo) + `SleepQualityRated` (1 toque) + `SleepLoggedManually` (fallback CSD 9 ítems) + `SleepEntryAmended`
- [ ] Puerto `SleepSource` + adaptador de Health Connect (dónde vive = decisión A-3 → ADR; sync pull al abrir la app)
- [ ] Read-side derivado: TST, sleep efficiency, WASO, latencia, calidad subjetiva
- [ ] Métricas cronobiológicas canibalizadas de la investigación de Gemini: MSFsc + social jetlag (MCTQ), con el método del intervalo más corto para el cruce de medianoche — descriptivas, NO intervención
- [ ] Integration event `sleep.night_logged` v1 (quality + tst_minutes)
- [ ] **Correlación estrella en el hub: `sueño(noche N) → ánimo(día N+1)`** con normalización z-score within-person y lag configurable (sin ella la asimetría causal desaparece, Triantafillou 2019)
- [ ] Gate de salida: `sleep` en uso diario real + la correlación estrella visible en el hub

## Hito 5 — Motor de correlación del hub (transversal, crece con Hitos 3–4)

No es un hito secuencial puro: el motor se construye incrementalmente al servicio de las correlaciones de Hito 3 y 4. Se lista aparte para no perderlo de vista.

- [ ] Normalización within-person (z-score por variable) ANTES de correlacionar — primer requisito, lo exige la correlación de Hito 3
- [ ] Lags configurables (sueño noche N → ánimo día N+1)
- [ ] Manejo de autocorrelación
- [ ] Output primario = inspección visual de series temporales (no p-values; literatura n-of-1 / SCED)
- [ ] **A-1 (ADR): ¿el motor vive en `hub` o en un paquete estadístico aparte sin Flutter?** — decisión arquitectónica a cerrar con ADR

## Hito 6 — Módulo `affect` (afecto momentáneo + escalas validadas)

El de mayor fricción; convierte el hub en motor de correlación pleno. Se empieza tras `sleep` en uso real.

- [ ] Paquete `packages/affect`: `MomentaryAffectSampled` (Affect Grid ESM 3–5×/día) + escalas periódicas `LifeSatisfactionRated` (SWLS), `AffectBalanceRated` (SPANE), `PersonalityAssessed` (BFI-2 baseline + re-test anual)
- [ ] Read-side: density distributions del afecto (media, varianza, skew, kurtosis — la varianza es tan informativa como la media)
- [ ] Integration events `affect.momentary_sampled` / `affect.balance_rated`
- [ ] Correlaciones cruzadas en el hub: afecto vs sueño, vs entreno
- [ ] Vigilar compliance del ESM: si cae, recortar a 1 captura/día o solo Affect Grid (fricción mínima)
- [ ] Gate de salida: `affect` en uso real con compliance sostenible

## Backlog lejano (sin orden ni compromiso)

Módulo `music` (escuchas + afecto antes/después, ideal pasivo) · módulo `context`/mobility (sensing GPS pasivo, alta complejidad/privacidad) · SRBAI / módulo de hábitos (canibalizado de Gemini, en pausa) · journaling · sync multi-dispositivo · versión web · snapshots (solo si algún stream duele). **Descartado con razón documentada** (`docs/design/modulos-post-mvp.md` §6): el módulo `chrono` intervencionista de Gemini — choca con la anti-meta de telemetría pura; adoptarlo exigiría un ADR que cambie VISION. **Descartado (2026-06-11):** "Repetir última rutina" — introduce semántica de "rutina" que no existe en el dominio y cuya utilidad no justifica añadir ese concepto antes de que el módulo gym esté bien sentado.

**Gym — baja prioridad, post-MVP estabilizado:** Temporizador de descanso observable (dato observado del tiempo entre series, no intervención/countdown). Solo se considera cuando el módulo gym esté en uso sostenido y sin pendientes UX. No entra antes.

## Riesgos vigilados

- **Sobre-ingeniería antes de uso real** → mitigación: gate de Hito 2 es uso, no features.
- **Versionado de eventos mal manejado al iterar gym** → mitigación: weak schema desde el primer evento; upcaster solo cuando duela.
- **Pérdida de rumbo entre sesiones** → mitigación: este roadmap + ADRs; toda sesión de diseño termina actualizándolos.
- **Pérdida de datos del dispositivo** (pasó el 2026-06-10: un `flutter run` reinstaló y borró todo; se restauró del backup adb). Causa raíz hallada al final del día: **el A71 estaba al 100% de almacenamiento** — el install fallaba y el fallback de `flutter run` es desinstalar (borrando datos). Mitigación: extraer la base tras cada entreno real mientras no exista export/backup desde la app; vigilar el espacio libre antes de instalar (`adb shell df -h /data`); preferir `adb push` + `pm install -r` (conserva datos y da el error real) sobre `flutter run` para desplegar; y recordar que `run-as` solo funciona con builds debug.
