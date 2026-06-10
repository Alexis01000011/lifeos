# ADR-0001: Event Sourcing puro con proyecciones síncronas

- **Fecha:** 2026-06-09
- **Estado:** aceptada

## Contexto

Decisión bloqueante pre-Fase 0: ¿cuál es la fuente de verdad de la persistencia — el log de eventos, o tablas de estado tipo CRUD? Restricciones: app local-first sobre un solo SQLite (Drift), un solo usuario, volumen bajísimo (decenas de eventos/día), objetivo explícito de aprendizaje de ES/CQRS a nivel industria.

## Opciones consideradas

**A. ES puro, proyecciones síncronas (elegida).** Eventos como única verdad; proyecciones actualizadas en la misma transacción SQLite que el append. Pro: una sola fuente de verdad, proyecciones desechables/reconstruibles, queries cómodas, auditabilidad y queries temporales gratis (es literalmente el dominio de la app: progreso en el tiempo). Con: versionado de eventos como costo permanente.

**B. ES puro estricto (proyecciones async).** Más fiel a sistemas distribuidos. Con: complejidad de consistencia eventual hoy, sin ningún beneficio en un solo dispositivo.

**C. Híbrido (tablas de estado como verdad operativa + eventos como log).** Pro: menos fricción inicial. Con: dos fuentes de verdad con riesgo de divergencia; la disciplina se erosiona hasta "CRUD con sabor a ES"; se pierde la garantía de reconstruibilidad; menor valor de aprendizaje.

## Decisión

Opción A. El argumento decisivo: el problema que hace dura la sincronía de proyecciones (distribución) no existe en un teléfono con un SQLite; podemos quedarnos la comodidad del híbrido sin pagar la doble verdad.

## Consecuencias

- Prueba ácida permanente: `DROP` de cualquier proyección + replay debe reproducir el estado exacto. Se automatiza como test.
- La interfaz `Projector` no asume sincronía (FutureOr), para no romper una futura versión con sync multi-dispositivo donde las proyecciones serían async.
- El write-side decide siempre rehidratando desde eventos, nunca leyendo proyecciones.
- Costo aceptado: versionado de eventos (weak schema + upcasters) desde el primer evento persistido.
- Agregados pequeños (Workout individual, no GymHistory) para que los streams se mantengan cortos; snapshots diferidos hasta que un stream duela.
