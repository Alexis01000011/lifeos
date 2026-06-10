# ADR-0006: adaptador core_drift con SQL crudo sobre la database compuesta de la app

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Fase 0b: hay que implementar el `EventStore` sobre Drift. Dos preguntas acopladas: dónde vive el adaptador, y cómo accede a SQLite. La restricción que manda es de ADR-0001: append de eventos y actualización de proyecciones deben ser atómicos. Las transacciones de Drift son *zone-based* — solo las operaciones sobre **la misma instancia de database** se unen a la transacción en curso. Por tanto, las tablas de eventos (infraestructura) y las tablas de proyección (de cada módulo) tienen que convivir en una sola database.

## Opciones consideradas

### Ubicación del adaptador

**A. Paquete `packages/core_drift` (elegida).** Depende de `core` + `drift`. Pro: `core` conserva su "cero dependencias" documentado; el adaptador hexagonal es literal (un paquete = un puerto implementado); los tests de integración de los módulos lo reutilizan sin depender de la app. Con: un paquete más.

**B. Dentro de la app shell.** Pro: una pieza menos. Con: la app no existe aún (Fase 3) y los tests de integración de gym (Fases 1-2) tendrían que depender de la app entera — invierte el grafo de dependencias.

**C. Dentro de `core`.** Con: rompe el "cero deps" de core; todo test de dominio arrastraría drift/sqlite3. Descartada.

### Acceso a SQLite

**A. SQL crudo sobre la GeneratedDatabase compuesta (elegida).** `DriftEventStore` recibe la database que la app componga y maneja sus dos tablas (`events`, `projection_checkpoints`) con `customSelect`/`customInsert`/`customStatement`, creándolas con `CREATE TABLE IF NOT EXISTS`. Pro: una sola database ⇒ una sola transacción zone-based ⇒ atomicidad de ADR-0001 garantizada; cero codegen en core_drift; el adaptador funciona contra cualquier database (en tests, una `GeneratedDatabase` mínima escrita a mano). Con: esas dos tablas pierden el type-safety de Drift.

**B. Database propia con codegen en core_drift.** Pro: type-safe. Con: dos instancias de database = dos conexiones ⇒ append y proyecciones **no** comparten transacción ⇒ rompe ADR-0001. Descartada por incompatible, no por gusto.

**C. Tablas en archivo `.drift` incluido por la database de la app.** Pro: type-safe. Con: el store necesitaría conocer la clase generada por la app — la infraestructura dependería del shell; resoluble con interfaces, pero es maquinaria pesada para dos tablas estables.

## Decisión

Paquete `core_drift` con SQL crudo sobre la database compuesta. Razón decisiva: la opción B rompe la atomicidad que es el corazón de ADR-0001, y la C invierte una dependencia para comprar type-safety en dos tablas de infraestructura que cambian casi nunca y están cubiertas por tests de integración contra SQLite real.

## Consecuencias

- Toda tabla de proyección de cualquier módulo debe vivir en **la misma database compuesta** que la app shell construye. Esto se vuelve parte implícita del contrato de módulo (se hará explícito al escribir el primer módulo).
- La app debe invocar `createEventStoreSchema(db)` en su arranque (idempotente).
- `core_drift` no usa build_runner: sus tests corren con una `GeneratedDatabase` mínima manual sobre `NativeDatabase.memory()`.
- Costo aceptado: las dos tablas de infraestructura se manipulan sin type-safety de Drift; mitigación: son estables y sus invariantes (orden, unicidad, atomicidad, rollback) tienen tests de integración dedicados.
- `global_sequence` es `INTEGER PRIMARY KEY AUTOINCREMENT` y `UNIQUE(aggregate_type, aggregate_id, stream_version)` actúa como red física de la concurrencia optimista bajo el chequeo de `expectedVersion`.
