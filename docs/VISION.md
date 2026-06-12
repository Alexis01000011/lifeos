# Visión — lifeos

> Documento norte. Si una decisión de código contradice algo de aquí, o se corrige el código o se actualiza este documento con un ADR — nunca se ignora en silencio.

## Qué es

Una app Android personal, modular y local-first: un *hub* de estadísticas de vida. Cada área (gimnasio, ánimo, música, journaling...) es un módulo independiente; el hub central agrega y correlaciona datos entre ellos. Es a la vez herramienta de uso diario y proyecto deliberado de aprendizaje de ingeniería a nivel industria.

**Usuario objetivo:** Alexis. Uno solo. Esto libera de muchas cosas (auth, multi-tenancy) y obliga a otra: la app tiene que ser tan cómoda que se use de verdad todos los días. Es una app de Alexis para Alexis.

## Principios (no negociables sin ADR)

1. **Local-first como paradigma, no como limitación.** Los datos viven en el dispositivo. Sin servidor pago. Futura versión web sincronizará dispositivo↔dispositivo, no dependerá de una nube.
2. **Los eventos son la única fuente de verdad** (ADR-0001). Todo estado consultable es derivado y reconstruible.
3. **Modularidad desde el día uno.** Un módulo nuevo no debe requerir tocar código de otro módulo. Si lo requiere, la frontera está rota.
4. **Aprendizaje con estándares de industria.** Se prefieren los conceptos reales (CQRS, bounded contexts, versionado de eventos) sobre atajos de principiante, aunque cuesten más.

## Stack

Flutter/Dart · Drift (SQLite) · Riverpod (estado + DI, ADR-0002) · Event Sourcing + CQRS + Pub/Sub · arquitectura hexagonal. Dispositivo objetivo: Samsung A71.

## Módulos

| Módulo | Estado | Dominio |
|---|---|---|
| **hub** | esqueleto (Fase 4) | Agregación y correlación entre módulos; pantalla de inicio |
| **gym** | en uso, rumbo a MVP (Hito 2) | Workouts, ejercicios, progresión de cargas |
| **days** | futuro (Hito 3, 2º módulo) | Calificar el día (nota 0–10 + tags); DRM-lite. Plan de telemetría en `docs/design/modulos-post-mvp.md` |
| **sleep** | futuro (Hito 4) | Diario de sueño (Consensus Sleep Diary); trae la correlación estrella sueño→ánimo |
| **affect** | futuro (Hito 6) | Afecto momentáneo (ESM/Affect Grid) + escalas validadas (SWLS, SPANE, BFI-2); vuelve al hub motor de correlación |
| **journal** | futuro | Journaling de texto libre |
| **music** | futuro (fase 2) | Escuchas y calificación de música |
| *...más* | futuro | Cualquier estadística personal que valga la pena medir |

**La pantalla principal es el hub.** Al abrir la app se ven las estadísticas que los módulos publican; esa misma pantalla es el punto de entrada hacia ellos (tocar una estadística navega al módulo). Los módulos se enchufan y desenchufan según su recurrencia en la vida de Alexis, y la pantalla principal refleja los activos sin que el resto se entere — es la cara visible de la Regla 1. La meta de fondo: registrar hoy con fricción mínima para correlacionar cuando haya volumen de históricos; las estadísticas ricas son consecuencia de los datos acumulados, no requisito de entrada de ningún módulo.

## Contrato hub ↔ módulo

Esta sección es la que protege el futuro. Todo módulo nuevo entra cumpliendo esto y *nada más que esto*:

**Anatomía de un módulo.** Cada módulo es un paquete Dart propio en `packages/<modulo>/` con su bounded context: sus agregados, sus domain events, sus proyecciones, sus pantallas. Posee sus datos: nadie más lee sus tablas.

**Regla 1 — Ningún módulo importa a otro módulo.** El grafo de dependencias permitido es: módulos → `core`; `hub` → `core`; la app shell → todos. Está prohibido `gym` → `days` o viceversa. La comunicación entre módulos pasa por el hub, siempre.

**Regla 2 — Domain events son privados; integration events son la API pública.** Los domain events (`WorkoutLogged`) son detalle interno del módulo y pueden cambiar con libertad. Cuando un módulo quiere anunciar algo al resto del sistema, publica un *integration event* (`gym.workout_completed`) — un contrato deliberadamente más chico, estable y versionado. Traducción explícita: un projector/policy del módulo escucha sus domain events y decide qué publicar.

**Regla 3 — El hub solo conoce integration events.** El hub se suscribe (pub/sub), mantiene sus propias proyecciones de correlación (p. ej. "ánimo vs. días de entreno") y jamás conoce los agregados internos de un módulo.

**Regla 4 — Los integration events se versionan como API pública.** Cambiarlos rompe a los suscriptores: mismo tratamiento que los domain events persistidos (weak schema + upcasters) pero con más conservadurismo.

**Checklist para agregar un módulo nuevo** (si algún paso requiere editar otro módulo, la arquitectura falló):

1. Crear `packages/<modulo>/` con dependencia solo a `core`.
2. Diseñar sus agregados y domain events (privados).
3. Definir qué integration events publica y/o consume (documentarlos en `docs/integration-events.md`).
4. Registrar sus proyecciones y pantallas en la app shell (providers Riverpod del módulo).
5. ADR si el módulo introduce alguna decisión arquitectónica nueva.

## Anti-metas

Para no perder el rumbo, lo que esta app NO es: no es un producto para terceros, no tiene backend propio, no persigue ingresos, y no se le agregan módulos antes de que el anterior esté en uso diario real. Funcionalidad usada > funcionalidad construida.
