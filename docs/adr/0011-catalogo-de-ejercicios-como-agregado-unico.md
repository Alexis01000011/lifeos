# ADR-0011: catálogo de ejercicios como agregado único con vinculación de nombres históricos

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

`SetLogged.exercise` es texto libre desde la Fase 1 ("el catálogo propio llega en Hito 2"). Sin identidad estable de ejercicio no hay PRs ni progresión por ejercicio: "Calves" y "calf raises" serían dos series sin relación. El A71 ya tiene 27 series reales repartidas en 7 nombres libres, y el inventario personal (`docs/gym_inventario.md`) lista ~30 ejercicios con grupos musculares estables. Hay que decidir la forma del agregado, cómo referencian las series al ejercicio, qué pasa con las series viejas, con qué metadata nace un ejercicio, cómo se tratan las variantes de equipamiento y cómo se puebla el catálogo.

## Opciones consideradas

### Forma del agregado

**A. `ExerciseCatalog` agregado único (elegida).** Un solo stream (`gym.exercise_catalog`/`catalog`) con eventos `exercise_added`/`exercise_renamed`. Pro: la unicidad de nombre es una validación *sobre el conjunto* (el problema clásico de set-validation en ES) y nuestra regla CQRS prohíbe que un handler la valide leyendo proyecciones — dentro del agregado que contiene el set completo es invariante de verdad, no best-effort. Stream acotado en la práctica (decenas de eventos). Con: rehidratación O(catálogo) en cada alta/rename (irrelevante local) y un stream que crece de por vida.

**B. Un agregado `Exercise` por ejercicio.** Pro: streams por entidad, historia de renombres aislada. Con: la unicidad de nombre queda huérfana — validarla contra un read model rompe la frontera write/read; aceptar duplicados socava el propósito del catálogo.

### Referencia de las series al ejercicio

**A. `exerciseId` + nombre denormalizado (elegida).** `set_logged`/`set_logged_late` ganan `exerciseId` opcional por weak schema (siguen v1; los persistidos quedan `null`) y conservan `exercise` como snapshot del nombre. Pro: evento autocontenido (replay sin joins, debugging legible) y el historial muestra el nombre tal como era ese día. Con: el nombre viaja duplicado; un rename no reescribe series pasadas (las vistas pueden resolver id→nombre actual si lo quieren).

**B. Solo `exerciseId`.** Pro: evento mínimo. Con: toda proyección que muestre nombre necesita join contra el catálogo y los eventos crudos son ilegibles.

### Series viejas a texto libre

**A. Vinculación por evento (elegida).** El catálogo mantiene el mapa "texto histórico → ejercicio": cada nombre que un ejercicio tuvo (el del alta y los previos a cada rename) queda vinculado automáticamente, y el alta acepta `legacyNames` explícitos para cuando difieran. Las proyecciones/estadísticas resuelven series sin `exerciseId` por ese mapa. Pro: el leg day real entra a PRs/tendencias; robusto a renombres; el mapeo es un hecho en el log. Con: invariante de unicidad extendida a nombres históricos (un nombre no puede pertenecer a dos ejercicios).

**B. Match por nombre en read-side sin evento.** Pro: cero conceptos extra. Con: un rename rompe el vínculo en silencio.

**C. Lo viejo queda fuera.** Pro: máxima simpleza. Con: el primer día real de datos queda huérfano. (Fue la primera intuición de Alexis; la descartó al ver que son 7 nombres que mapean casi 1:1 a ejercicios que va a crear igual.)

### Metadata, variantes y semilla

- **Nace con nombre + grupo muscular primario.** Los grupos reales ya son estables y planos (pecho, hombro, tríceps, espalda, bíceps, pierna, abdomen — enum en el módulo, string estable en el payload). Diferirlo ahorraba poco: el alta de ~30 ejercicios cuesta lo mismo con o sin grupo, y la estadística "volumen por grupo" del hito lo consume.
- **Variantes = entradas separadas** ("Press plano (barra)" y "Press plano (smith)" son ejercicios distintos): PRs y progresión correctos por definición; una relación de agrupamiento se agrega el día que una estadística la pida.
- **Semilla manual por pantalla de catálogo** guiada por `gym_inventario.md` (+ creación al vuelo durante el registro). Un importador del .md sería código de un solo uso. El inventario es una *rutina* (planificación); ese concepto queda explícitamente fuera del catálogo y de este hito.

## Decisión

Catálogo agregado único (A) + id con nombre denormalizado (A) + vinculación de nombres históricos por evento (A) + nombre y grupo muscular al nacer + variantes como entradas separadas + carga manual. Eventos nuevos: `gym.exercise_added` v1 (`exerciseId`, `name`, `muscleGroup`, `legacyNames` opcional) y `gym.exercise_renamed` v1 (`exerciseId`, `newName`). Comandos `AddExercise`/`RenameExercise`; el handler del alta crea el agregado singleton si no existe (load-or-create).

Read-side: `gym_exercises` (una fila por ejercicio) y `gym_exercise_names` (mapa nombre normalizado → ejercicio, incluye nombres históricos), proyectadas por `ExerciseCatalogProjector` (`gym.exercises`, nombre nuevo → checkpoint 0 → el catch-up del arranque lo puebla, mecánica de ADR-0010).

## Consecuencias

- El agregado `Workout` NO valida que `exerciseId` exista en el catálogo: sería una invariante entre agregados (no hay transacción que las cubra honestamente). La UI selecciona del catálogo, así que el id es válido por construcción; un id colgado sería defecto cosmético, no corrupción.
- `gym_sets` no cambia en esta fase: los eventos ya llevan `exerciseId` y la columna se agregará cuando la primera estadística la consuma (reformando el projector con la mecánica de rename + catch-up de ADR-0010). Decisión consciente de no construir read model sin consumidor.
- La unicidad cubre nombre actual + históricos + legacy, normalizados (trim + case-insensitive). Un nombre liberado por rename sigue perteneciendo al ejercicio viejo a efectos de resolución; reutilizarlo en otro ejercicio está prohibido por el agregado.
- Borrar/archivar ejercicios queda fuera de v1 (YAGNI hasta que el catálogo crezca o estorbe); cuando llegue, será otro evento, no un DELETE.
- El registro durante el entreno pasa de texto libre a selección del catálogo (con alta al vuelo). El texto libre muere como entrada, no como dato: los eventos viejos se resuelven por el mapa de nombres.
