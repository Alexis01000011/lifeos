# ADR-0008: read models de módulos con SQL crudo y notificaciones manuales

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Fase 2: los módulos necesitan tablas de proyección propias. Por ADR-0006 deben vivir en la database compuesta (una sola transacción zone-based con el append). La pregunta: ¿cómo las define y accede el módulo? La decisión condiciona la reactividad de Fase 3: los streams nativos de Drift (`watch()`) requieren tablas declaradas con codegen; la alternativa es la API pública de notificaciones (`notifyUpdates`/`tableUpdates`).

## Opciones consideradas

**A. SQL crudo + notifyUpdates (elegida).** El módulo crea sus tablas con `CREATE TABLE IF NOT EXISTS` y opera con `customStatement`/`customSelect`; tras cada escritura notifica `TableUpdate(nombreDeTabla)`. Pro: cero codegen en el repo, coherente con ADR-0006, verificado hoy (compiló y los tests pasan); los módulos dependen solo del runtime de drift. Con: sin type-safety en read models; la reactividad de Fase 3 se arma a mano (helper pequeño: `tableUpdates` + re-query).

**B. Drift modular con codegen.** Cada módulo declara tablas Drift con `drift_dev` en modo modular; la app las incluye. Pro: type-safety y `watch()` nativo. Con: build_runner en cada módulo, y la composición DAO↔database entre paquetes está poco documentada (los DAOs se atan a una clase de database concreta) — se verificó en la documentación oficial antes de decidir; resolverlo exigiría experimentación justo en el hito que valida la arquitectura.

**C. Diferir a Fase 3.** Hacer Fase 2 con SQL crudo "provisional" y decidir al construir la UI. Con: riesgo de reescribir proyecciones recién hechas; además A ya es reversible por ADR si duele.

## Decisión

Opción A. Razón decisiva: mantiene todo el repo sin codegen con un único patrón de acceso a datos, y el costo real (type-safety en tablas chicas + reactividad artesanal) es conocido y acotado, mientras que el costo de B es incierto. Si la reactividad manual o la falta de tipos duele al crecer los módulos, se migra con un ADR que reemplace a este.

## Consecuencias

- Patrón por módulo: `create<Modulo>ReadModelSchema(db)` idempotente (la app lo llama al arrancar), projectors con SQL crudo que terminan en `notifyUpdates`, y una clase de consulta (`GymReadModels`) que devuelve DTOs.
- Los projectors con acumuladores (`+=`) NO son idempotentes por sí solos: dependen de la guarda de checkpoint del `ProjectionEngine`. Documentado en el código; la prueba ácida lo cubre.
- Fase 3 necesita un helper de streams (tableUpdates → re-query) en core_drift o en la app. *(Resuelto en Fase 3: `watchQuery` en core_drift — es infraestructura genérica reutilizable por cualquier módulo y testeable sin Flutter. Implementado con StreamController explícito, no `async*`: un generador suspendido esperando una notificación que no llega no puede cancelarse, y el cancel de la UI quedaría colgado.)*
- Los módulos ganan dependencia al runtime de `drift` (framework, no módulo: la regla de fronteras no se toca) y a `core_drift` solo en dev_dependencies (tests de integración).
- El bucketing semanal usa la semana ISO del `occurredAt` en UTC: simplificación aceptada del esqueleto, a revisar en Hito 2 junto con el tiempo de negocio (ADR-0003).
