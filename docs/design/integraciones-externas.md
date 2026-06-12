# Diseño — integraciones externas (clima · nutrición vía Health Connect)

> **Estado:** idea capturada en sesión 2026-06-11. NO es compromiso de roadmap ni hito; horizonte post-Hito 7 / fase 2. El gate de VISION sigue intacto: ningún módulo nuevo antes de que el anterior esté en uso diario real. Este documento existe para que la idea no se relitigue desde cero en una sesión futura.

## 1. Principio rector: las APIs externas son adaptadores de captura

Una API externa no es un módulo ni una excepción arquitectónica — es un **adaptador de entrada** (hexagonal), igual que la UI. La ingesta se traduce a eventos propios y se appendea; el event store local sigue siendo la única fuente de verdad y **el replay jamás toca la red**. Cumplido eso, la prueba ácida sobrevive y local-first no se viola: la red es mecanismo de captura, no dependencia de runtime.

Requisitos de todo adaptador de ingesta:

1. **Anti-corruption layer** — el schema externo es volátil; se traduce a eventos propios, nunca se persiste crudo como contrato.
2. **Idempotencia de ingesta** — re-consultar lo mismo no duplica eventos. Dedup por clave natural: fecha+ubicación para clima, record-id para Health Connect.
3. **Semántica de hecho observado** — los eventos se nombran como observaciones (`WeatherObserved`, `NutritionObserved`), no como acciones del usuario.

## 2. Clima

- Fuente candidata: **Open-Meteo** — gratis para uso no comercial, sin API key, histórico horario desde 1940 (`/v1/archive`) por coordenadas.
- **El clima es backfillable retroactivamente** por fecha+ubicación → cero urgencia de capturar hoy. Cuando el módulo exista, se rellena todo el histórico de golpe y se correlaciona contra los datos que los demás módulos ya hayan acumulado.
- Decisión abierta (ADR cuando se aborde): ¿módulo `weather` que publica integration events (uniformidad con Regla 3) o covariable exógena que el hub ingesta directo? Clima es contexto, no telemetría personal — sería el primer dato no-conductual del sistema.

## 3. Nutrición vía Health Connect

- **Pipeline:** MyNetDiary → Health Connect (datastore *on-device* → encaja con local-first de fábrica) → lifeos. Evita diseñar UI de captura y base de datos de alimentos propias.
- Ruta SDK de Samsung Health **descartada como principal**: exige partnership para distribución; su developer mode es solo para pruebas. Health Connect es API abierta.
- Flutter: el paquete `health` soporta Health Connect incluida nutrición.
- **Hallazgos empíricos (2026-06-11, A71, 2 comidas de prueba):** los registros llegan con `Name` + `Meal type` + desglose amplio de macro y micronutrientes (gramos por nutriente). El tubo es ancho → un futuro módulo de nutrición puede modelar a nivel comida, no solo totales diarios. Patrón sugerido: **capturar rico** (el evento persiste el desglose completo observado), **publicar chico** (integration event mínimo al hub — p. ej. fecha + kcal + proteína — y crecer por weak schema).
- Restricción de Health Connect: por defecto solo se leen 30 días previos al primer grant de permiso; existe `PERMISSION_READ_HEALTH_DATA_HISTORY`, pero solo lee lo que ya esté en HC — lo anterior a activar el sync nunca llega. **Sync activado el 2026-06-11** → los datos se acumulan desde hoy. Backfill más profundo: export CSV de MyNetDiary.
- **Checks resueltos (2026-06-11, validación empírica en el A71):**
  - (a) Granularidad: **1 registro por comida** (2 comidas registradas → 2 entradas en HC), cada una con su desglose completo. ✅
  - (b) Origen: **único — MyNetDiary** escribe directo a HC; Samsung Health no duplica los registros. Sin problema de dedup entre orígenes. ✅
  - El pipeline MyNetDiary → Health Connect quedó validado de punta a punta sin código.

## 3b. Claude ↔ Health Connect: instrumento de exploración, no arquitectura

La app de Claude para Android puede leer Health Connect (integración lanzada por Anthropic en enero 2026; al lanzamiento, solo suscriptores Pro/Team en EE. UU.). Dos usos legítimos para lifeos: **lupa de diseño** (inspeccionar conversacionalmente qué campos llegan a HC, con qué calidad y huecos, antes de diseñar el módulo de nutrición) y **preview exploratorio de hipótesis** cuando haya meses de datos (decidir *qué* correlacionar formalmente — hipótesis, no hechos, mismo rol que los estudios poblacionales en `modulos-post-mvp.md` §1.2).

**Límite explícito:** lifeos nunca depende de esto. Es nube (viola local-first, VISION 1) y es análisis a ojo sin normalización within-person — lo que el motor del hub existe para hacer bien.

## 4. Tensión a vigilar

Health Connect también expone sueño medido por sensor. El módulo `sleep` (Hito 4) ya eligió el diario subjetivo CSD con advertencia explícita contra el sensor como verdad (`modulos-post-mvp.md` §4). La existencia del adaptador será tentación futura; cambiar esa decisión exigiría ADR, no un atajo.

## 5. Qué NO es esto

No entra a `ROADMAP.md` hoy ni define módulos nuevos. La conversión a hito tendrá su propia sesión de diseño cuando el gate de uso real lo permita (anti-meta: funcionalidad usada > construida).
