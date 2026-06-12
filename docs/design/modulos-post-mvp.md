# Diseño general — módulos de telemetría post-MVP

> **Estado:** diseño aprobado en sesión 2026-06-11. NO es implementación. Es el plano que la próxima sesión convierte en hitos del ROADMAP. Cada módulo aquí descrito entra al repo cumpliendo el contrato hub↔módulo de `VISION.md` y *nada más que eso*.
>
> **Fuente:** investigación de evidencia científica (handoff de Claude/Fable 5, `Investigacion_Claude.md`), cotejada contra la investigación paralela de Gemini (`...Gemini.md`). El diseño se basa principalmente en la de Claude por tener contexto real de la app; de la de Gemini se canibaliza lo accionable (ver §6).

## 0. Por qué este documento existe

El MVP (gym) demuestra la arquitectura con UN módulo y CERO correlaciones reales entre módulos. La promesa de fondo de lifeos —"registrar hoy con fricción mínima para correlacionar cuando haya volumen de históricos"— sigue sin probarse. Estos tres módulos nuevos existen para cumplir esa promesa:

- **`days`** valida que el checklist de "agregar un módulo" funciona sin tocar gym ni core (ya estaba previsto como 2º módulo en VISION por su simpleza).
- **`sleep`** trae la correlación intermódulo de mayor relación evidencia/valor de toda la app (sueño → ánimo del día siguiente).
- **`affect`** convierte el hub en un motor de correlación de verdad, no en un contador de entrenos.

El orden no es negociable y se justifica en §2.

## 1. Principios que rigen TODO este diseño

Tres restricciones, encima de las de `VISION.md`, gobiernan cada decisión de abajo. Si una pantalla o un evento las contradice, está mal diseñado.

**1.1 — Telemetría pura, no intervención.** La app mide; no motiva, no gamifica, no "optimiza al usuario". Métricas incómodas (el U-index, un mal score de sueño) se muestran sin suavizar. Esto es anti-meta de `VISION.md` y es la razón principal por la que el módulo `chrono` de Gemini se descarta como tal (§6): su naturaleza es intervencionista (suprimir notificaciones, forzar pausas, "andamiaje cognitivo"), lo que convertiría a lifeos en un coach. lifeos es un instrumento de medición.

**1.2 — No-ergodicidad: los datos poblacionales son hipótesis, no hechos** (Fisher, Medaglia & Jeronimus 2018, *PNAS*). Ningún effect size de los estudios (el `b=0.344` del sueño, la `g=0.336` del ejercicio) es el de Alexis. El motor del hub **estima los parámetros propios de Alexis** sobre sus propias series temporales. Todo análisis es intra-persona. Los hallazgos de grupo solo sirven para decidir *qué* medir, jamás para afirmar *qué le pasa a Alexis*.

**1.3 — Fricción mínima como requisito de supervivencia.** "Una app de Alexis para Alexis" solo sirve si se usa todos los días. La fricción de captura es el presupuesto más escaso del sistema y se gasta con avaricia: `days` cuesta 1 toque/día, `sleep` 1 formulario/mañana, `affect` es el más caro y por eso va al final. Si el compliance cae, se recorta la captura antes que abandonar el módulo.

## 2. Orden de construcción y su lógica

```
gym (MVP) ──> days ──> sleep ──> affect ──> [fase 2: music, context]
              │         │          │
              fricción  evidencia  hub se vuelve
              mínima,   /valor     motor de
              valida    máxima     correlación
              modular.
```

- **`days` primero** porque es el módulo más simple después de gym, la máxima evidencia (DRM) y la mínima fricción (1 captura/día). Su valor de ingeniería es probar la modularidad en frío. Su valor de producto es dar la **primera serie temporal correlacionable** (nota del día).
- **`sleep` segundo** porque sin él no hay correlación estrella. `sleep(noche N) → day_rating(día N+1)` es el hallazgo con mayor evidencia y el primero que junta dos módulos en el hub. Construirlo después de `days` significa que en cuanto exista, ya hay un segundo eje (la nota diaria) contra el cual cruzarlo.
- **`affect` tercero** porque es el de mayor fricción (ESM 3–5 prompts/día) pero el que vuelve al hub un motor real: introduce afecto momentáneo + escalas validadas (SWLS, SPANE, BFI-2) y habilita las correlaciones cruzadas ricas.

**Gate entre módulos (igual que el gate de Hito 2):** un módulo nuevo no se empieza hasta que el anterior esté en **uso diario real**, no solo construido. Anti-meta de VISION: funcionalidad usada > funcionalidad construida.

## 3. Módulo `days` — calificación diaria (DRM-lite)

**Bounded context:** el día como unidad calificable. Posee sus datos; nadie más lee sus tablas.

**Alcance v1 (decidido 2026-06-11): solo `DayRated` + tags.** Los episodios DRM completos (`DayEpisodeLogged`, ~14 episodios/día) se diseñan conceptualmente aquí pero quedan como extensión posterior del *mismo* módulo, no como v1. Razón: 14 episodios/día es fricción alta que arriesga el hábito antes de formarlo. La nota global + tags ya da la unidad de correlación.

### Dominio

- **Agregado `Day`** (uno por fecha de calendario). Ciclo de vida trivial: una fecha se califica a lo sumo... bueno, ver decisión abierta D-1 (¿re-calificable?). Identidad = la fecha local (`StreamId` derivado de `YYYY-MM-DD`). Análogo al `Workout` como ciclo de vida (ADR-0007), pero mucho más simple.

### Domain events (privados del módulo)

| Evento | Payload (campos núcleo) | Notas |
|---|---|---|
| `DayRated` | `{ date, score (0–10 int), tags: [string] }` | 1×/día. La nota global y los tags en un solo evento. `score` entero 0–10 = baja fricción (vs Affect Grid, que se reserva para `affect`). |
| `DayRatingAmended` | `{ date, newScore?, addedTags?, removedTags? }` | Corrección vía evento, nunca UPDATE (ADR-0001). Resuelve "califiqué mal ayer". Análogo en espíritu a `set_logged_late`/`workout_discarded` de gym (ADR-0010). |

Los **tags son la unidad de correlación con afecto** (réplica n=1 de la tabla de Kahneman: net affect por tipo de actividad). Tags libres en v1; se puede sugerir un set semilla inspirado en el DRM original (trabajar, commute, comer, socializar, relajarse, tareas, ejercicio, ocio pasivo…) sin imponerlo.

### Integration events

- **Publica `days.day_rated` v1** — contrato deliberadamente chico para el hub:
  ```json
  { "date": "2026-06-11", "score": 7 }
  ```
  NO incluye tags en v1 (weak schema: agregarlos después es barato). El hub solo necesita la serie temporal de la nota para la primera correlación. Si una corrección cambia la nota, se publica un `days.day_rating_amended` compensatorio (mismo patrón que `gym.workout_discarded`), o se difiere la corrección al hub hasta tener el caso real — decisión abierta D-2.
- **Consume:** nada en v1. (En el futuro podría consumir `gym.workout_completed` para auto-taggear "ejercicio", pero eso acopla y se evita hasta que haya necesidad real.)

### Read-side (proyecciones, SQL crudo estilo ADR-0008)

- Serie temporal de la nota diaria (para graficar y exportar al hub).
- **Net affect por tag**: ranking personal de qué tags co-ocurren con mejor/peor nota. Es la métrica estrella del módulo y el embrión de la tabla de Kahneman n=1.
- (Diferido a la extensión DRM) **U-index personal**: proporción de episodios del día en estado desagradable. Requiere `DayEpisodeLogged`, no entra en v1.

### Pantallas

- **Calificar hoy**: un slider/stepper 0–10 + chips de tags. Objetivo: < 5 segundos.
- **Historial de días**: lista + mini-gráfica de la nota; ranking de tags por net affect cuando haya volumen.
- Registra su tarjeta en el hub ("nota de hoy" / "racha de registro"), igual que gym registró "entrenos esta semana".

### Evidencia

Kahneman et al. (2004, *Science* 306:1776) DRM; Kahneman & Krueger (2006) U-index; Lyubomirsky/Sheldon/Schkade (2005) como marco (foco en actividades intencionales → los tags son las "actividades intencionales" rastreables).

## 4. Módulo `sleep` — diario de sueño (CSD + Health Connect)

**Bounded context:** la noche como unidad medible. El módulo de mayor relación evidencia/valor.

**Estrategia de captura (decidida 2026-06-11): híbrida.** Samsung Health ya escribe sesiones de sueño a **Health Connect** (API local de Android — los datos viven en el dispositivo, compatible con local-first). El módulo importa de ahí los *tiempos* (acostarse, dormir, despertares, levantarse) y solo pide manualmente lo que el sensor no sabe: la **calidad subjetiva (1 toque, Likert 1–5)**. Razón para conservarla: el hallazgo estrella de Triantafillou (2019) se midió con calidad *subjetiva*, no con duración medida — eliminarla debilitaría justo la variable de la correlación estrella. Fricción resultante: de 9 ítems/mañana a ~1 toque/mañana.

### Dominio

- **Agregado `SleepEntry`** (uno por noche / fecha de despertar). Se alimenta de dos fuentes: la importación de HC y la calificación manual.

### Domain events

| Evento | Payload | Notas |
|---|---|---|
| `SleepSessionImported` | `{ date, externalId, source: "health_connect", inBedTime?, sleepStart, sleepEnd, awakenings?[…] }` | **La importación misma es un evento** (con provenance + id externo): idempotente por `externalId`, y el replay jamás re-lee Health Connect — la fuente de verdad sigue siendo el event store, HC es solo el origen del dato. |
| `SleepQualityRated` | `{ date, qualityRating (Likert 1–5), notes? }` | El toque manual de la mañana. |
| `SleepLoggedManually` | los 9 ítems core del CSD (Carney et al. 2012, *SLEEP* 35(2):287) | **Fallback** para noches sin sesión en HC (sensor falló, teléfono apagado). El instrumento validado completo sigue disponible. |
| `SleepEntryAmended` | corrección vía evento compensatorio (ADR-0001 / patrón ADR-0010) | |

### Puerto/adaptador (hexagonal)

`packages/sleep` depende solo de `core` (Regla 1): el módulo define un **puerto** (`SleepSource`) y el adaptador de Health Connect vive aparte — análogo al split `core`/`core_drift` (ADR-0006). Dónde exactamente (paquete `sleep_health_connect` vs adaptador en la app shell) es la decisión abierta **A-3** (§9). Sincronización pull al abrir la app (sin background jobs en v1).

### Read-side (todo derivable de los 9 ítems)

- **TST** (total sleep time), **sleep efficiency** (% dormido sobre tiempo en cama), **WASO**, **latencia**: cálculos puros sobre el evento.
- Serie temporal de calidad subjetiva.
- **Métricas cronobiológicas canibalizadas de Gemini** (ver §6): **MSF**, **MSFsc** (punto medio corregido por deuda de sueño) y **social jetlag** (SJL = |MSF − MSW|). Salen gratis de los mismos 9 ítems + marcar día laboral/libre. Son proyecciones derivadas *descriptivas* dentro de `sleep`, NO disparadores de intervención. Ojo con el "problema de los dos intervalos" (resta de horas que cruzan medianoche): usar el método del intervalo más corto en espacio circular de 24h.

### Integration events

- **Publica `sleep.night_logged` v1**:
  ```json
  { "date": "2026-06-11", "quality": 4, "tst_minutes": 415 }
  ```
  Contrato chico: lo que el hub necesita para la correlación estrella. `tst_minutes` y `quality` bastan; MSFsc/SJL son internos a `sleep` salvo que el hub demuestre necesitarlos (entonces, weak schema: se agregan).
- **Consume:** nada.

### Correlación estrella (la diseña el hub, §5)

`sleep(noche N) → day_rating(día N+1)`. Hallazgo de Triantafillou et al. (2019, *JMIR Mental Health* 6(3):e12613): within-person, sueño → ánimo del día siguiente (`b=0.344`) ≫ ánimo → sueño (`b=0.132`). **Crítico para el diseño del hub:** la asimetría SOLO emerge tras **normalización z-score within-person**; en scores crudos los efectos eran casi iguales y no significativos. Por eso §5.1 hace de la normalización within-person un requisito del motor, no un extra.

### Advertencias

El diario subjetivo no es polisomnografía, y **el sueño estimado por Samsung Health tampoco**: es otra estimación, no "la verdad". La advertencia de la investigación (no tratar sensores de movimiento como verdad sin validación) se honra así: los tiempos importados son *datos con provenance*, comparables contra la percepción propia. Si tras semanas de datos la duración importada y la calidad subjetiva no se relacionan en nada, eso es información, no error (no-ergodicidad, §1.2).

## 5. El hub como motor de correlación (transversal)

Hoy el hub solo cuenta entrenos. Estos módulos lo obligan a crecer a lo que VISION siempre prometió: agregación y **correlación** entre módulos. El hub sigue respetando Regla 3 (solo conoce integration events, jamás agregados internos de un módulo).

### 5.1 Requisitos del motor estadístico (se construyen incrementalmente, no de golpe)

1. **Series temporales intra-persona** sobre los integration events que ya recibe (nota diaria, sueño, después afecto).
2. **Normalización within-person (z-score por variable)** ANTES de correlacionar. No es opcional: swithout ella la asimetría causal del sueño desaparece (Triantafillou 2019). Es el primer requisito que se implementa.
3. **Lags configurables** (p. ej. sueño noche N → ánimo día N+1). El hub debe poder desfasar series.
4. **Manejo de autocorrelación** (las series propias están autocorrelacionadas; ignorarlo infla correlaciones espurias).
5. **Output primario = inspección visual de series temporales**, no p-values. La literatura n-of-1 / SCED prioriza la gráfica sobre la inferencia. Las correlaciones n=1 son exploratorias/descriptivas, no inferenciales.

### 5.2 Primera correlación a entregar

`ánimo (days) vs. días de entreno (gym)` ya estaba prevista en el Hito 3 original. Con `sleep` se suma la de mayor evidencia: `sueño → ánimo día siguiente`. Estas dos son el primer producto real del motor.

### 5.3 Decisión arquitectónica latente (candidata a ADR)

¿El motor de correlación vive **dentro del paquete `hub`** o en un **paquete `core` estadístico** reutilizable? Hoy parece que dentro de `hub` (es consumidor de integration events, encaja en Regla 3). Pero si el cálculo se vuelve pesado y testeable de forma aislada, podría justificar su propio paquete sin dependencias de Flutter (como `core` no depende de Drift). **Esto es una decisión con consecuencias arquitectónicas → ADR cuando se aborde.** Ver §8, A-1.

## 6. Qué se toma de la investigación de Gemini y qué se descarta

Gemini propuso un único módulo `chrono` (Engine de Regulación Cronobiológica). Decisión de la sesión: **canibalizar lo accionable, descartar el módulo**.

**Se toma (entra como proyecciones derivadas de `sleep`, §4):**
- Cálculo de **MSFsc** y **social jetlag (MCTQ)**. Son métricas descriptivas valiosas que salen gratis de los 9 ítems del CSD + marca laboral/libre. La trampa matemática del "problema de los dos intervalos" (resta de medianoche) es real y su solución (intervalo más corto en espacio circular) se adopta.

**Se manda al backlog lejano:**
- **SRBAI** (índice de automaticidad de hábito, 4 ítems semanales). Útil y de baja fricción, pero presupone que lifeos "rastrea hábitos", lo cual es una semántica de producto que aún no existe. Se reconsidera si algún día hay un módulo de hábitos.

**Se descarta (con razón documentada, para que la próxima sesión no lo relitige):**
- El **módulo `chrono` como tal** y todo su andamiaje intervencionista: supresión de notificaciones, detección de "fatiga prefrontal" por variabilidad de digitación, prompts de pausa ART, "andamiaje cognitivo", clasificación en canales de flujo con respuestas del sistema. **Choca de frente con la anti-meta de telemetría pura (§1.1):** convierte la app en un coach que actúa sobre Alexis. lifeos mide, no interviene. Adoptarlo requeriría un ADR que *cambie VISION*, no un simple módulo nuevo.
- El **ESM de flujo (challenge/skill → cuadrantes)** de Gemini se subsume en el `affect` de la investigación de Claude (Affect Grid: valencia + activación), que es más simple, igual de validado y no arrastra la maquinaria de intervención. La normalización z-score within-person que Gemini propone para el flujo es exactamente la que §5.1 ya exige para todo.
- El **código Dart de muestra de Gemini se ignora**: usa `DateTime.now()` dentro del agregado (viola la pureza de `apply()`, ADR-0003), define su propio event store por módulo (contradice `core_drift` como adaptador único, ADR-0006) e inventa un `IntegrationEventPublisher` que no es el log-outbox de ADR-0009. Es incompatible con la arquitectura real del repo.

## 7. Módulo `affect` — afecto momentáneo + escalas validadas (HUB de correlación)

El de mayor fricción y el que convierte al hub en motor real. Se construye al final a propósito.

### Dominio

- **Agregado `AffectLog`** para muestreo momentáneo; **agregados/eventos separados** para las escalas periódicas (distinta cadencia, distinta semántica).

### Domain events

| Evento | Cadencia | Payload |
|---|---|---|
| `MomentaryAffectSampled` | ESM, 3–5×/día semi-aleatorio | Affect Grid: `{ at, pleasure (1–9), arousal (1–9) }` — un solo toque en grid 9×9 da valencia + activación simultáneas (Russell et al. 1989). Alternativa "bag of items" 2–4 ítems 0–6. |
| `LifeSatisfactionRated` | mensual/trimestral | SWLS: 5 ítems exactos (Diener et al. 1985), escala 1–7, total 5–35 con bandas interpretativas. |
| `AffectBalanceRated` | semanal/mensual | SPANE: 12 ítems (6+, 6−), 1–5 frecuencia → SPANE-P, SPANE-N, SPANE-B = P−N. |
| `PersonalityAssessed` | baseline + re-test ~anual | BFI-2 (Soto & John 2017), 60 ítems, 5 dominios + 15 facetas. **Es parámetro base estable, NO se trackea diario** (Mõttus 2024: LS se predice de rasgos con rtrue≈.80–.90). |

### Read-side

- **Density distributions del afecto** (Fleeson 2001): media, varianza, skew, kurtosis del afecto propio. **La varianza es tan informativa como la media** — la personalidad-como-estado varía enormemente within-person.
- Series de SWLS/SPANE para el "remembering self"; afecto momentáneo agregado para el "experiencing self". Se capturan **ambos** a propósito (Kahneman): pueden divergir.

### Integration events

- **Publica `affect.momentary_sampled` v1** (`{ at, pleasure, arousal }`) y `affect.balance_rated` (SPANE-B), para que el hub cruce afecto vs sueño, vs entreno, vs música.
- **Consume:** nada (es productor de la señal que el resto correlaciona).

### Advertencias

Reactividad/habituación (el afecto positivo reportado decae con muestreo prolongado — es habituación, no cambio real). 3–5 prompts/día es la fricción más alta del sistema: si el compliance cae, recortar a 1 captura/día o solo Affect Grid (§1.3). Ítems del PANAS son © APA; SWLS/SPANE/BFI-2 libres para uso personal con atribución — el uso de Alexis encaja.

## 8. Fase 2 (sin compromiso de fecha)

- **`music`** — `MusicListenLogged` (idealmente pasivo vía scrobbling local): track/género/contexto + afecto antes/después. Hallazgo a replicar (Randall & Rickard 2017): escuchar "para evadir problemas" se asocia con peor afecto. **Dirección causal ambigua** → exige análisis temporal antes/después. Ya estaba en VISION como módulo futuro.
- **`context`/mobility** — sensing pasivo de GPS (location variance, entropy, circadian movement, home stay). Correlaciones |r|≥0.4 con síntomas depresivos entre-persona (Saeb 2015). **Baja prioridad, alta complejidad:** privacidad fuerte, validez n=1 es hipótesis no hecho, y Saeb excluyó 30% de su muestra por datos GPS insuficientes. Solo si la complejidad/privacidad se justifican.

## 9. Decisiones abiertas (candidatas a ADR cuando se implementen)

Ninguna se cierra hoy; se listan para que la sesión de implementación las vea venir y no las relitigue por accidente.

- **A-1 — ¿Motor de correlación en `hub` o en un paquete estadístico aparte?** (§5.3). Consecuencia arquitectónica → ADR.
- **D-1 — ¿`Day` es re-calificable el mismo día o inmutable una vez calificado?** Afecta el ciclo de vida del agregado. Recomendación tentativa: re-calificable vía `DayRatingAmended` (consistente con ES: corrección por evento, no por UPDATE).
- **D-2 — ¿Las correcciones de `days`/`sleep` se propagan al hub como integration events compensatorios** (estilo `gym.workout_discarded`, ADR-0010) **o se difiere hasta tener el caso real?** Recomendación: diferir; publicar el compensatorio recién cuando exista la pantalla de corrección.
- **A-3 — ¿Dónde vive el adaptador de Health Connect?** (§4). Opciones: paquete propio `sleep_health_connect` (simétrico a `core`/`core_drift`, testeable aislado) vs adaptador en la app shell (menos paquetes, pero la app shell acumula infraestructura de un módulo específico). Consecuencia arquitectónica → ADR al implementar Hito 4. Incluye decidir el plugin Flutter concreto (p. ej. `health`) y el manejo de permisos de HC.
- **A-2 — Migrar `DomainException` a errores tipados por módulo.** Ya pactado en ADR-0005: el trigger es el 2º módulo. **`days` ES ese 2º módulo** → este diseño *dispara* esa migración. La reemplaza un ADR nuevo. (Ya estaba anotado en el Hito 3 original del roadmap.)
- **D-3 — Set de tags de `days`: libre, semilla sugerida, o cerrado.** Recomendación: libre con semilla opcional (no imponer taxonomía; los tags son del usuario).

## 10. Cómo esto cambia el roadmap

Este diseño reescribe el Hito 3 en adelante. El `days` que el roadmap ya mencionaba ("trivial en dominio, su valor es probar el checklist de módulo") se mantiene como primer paso; encima se encadenan `sleep` y `affect` con sus gates de uso real, y el motor de correlación del hub crece en paralelo. Ver `ROADMAP.md`.
