# ADR-0005: DomainException con string; errores tipados diferidos al segundo módulo

- **Fecha:** 2026-06-10
- **Estado:** aceptada

## Contexto

Pregunta abierta de Fase 0: ¿alcanza `DomainException(message)` con un string, o conviene una jerarquía de errores tipados por módulo desde ya? El único consumidor previsto en el walking skeleton y el MVP es la UI mostrando el mensaje (snackbar/diálogo).

## Opciones consideradas

**A. String, por ahora (elegida).** Pro: cero boilerplate antes de tener invariantes reales que lo justifiquen; suficiente mientras el único uso sea "mostrar mensaje". Con: la UI no puede discriminar por tipo de error (reaccionar distinto según cuál invariante falló), y los mensajes de dominio quedan acoplados a la presentación.

**B. Errores tipados por módulo desde ya.** Pro: discriminación exhaustiva en la UI, mensajes desacoplados del dominio. Con: diseño especulativo — todavía no existe ni un agregado con invariantes; el costo de migrar después es mecánico (introducir subclases y reemplazar construcciones), así que pagar ahora no compra nada.

## Decisión

Opción A, con trigger de migración explícito: **al crear el segundo módulo (days, Hito 3) se migra a errores tipados por módulo.** Para entonces gym habrá acumulado invariantes reales que informen el diseño de la jerarquía, y el checklist de "agregar un módulo" es el momento natural de fijar el patrón que todos los módulos seguirán.

## Consecuencias

- `DomainException` se queda como está en `packages/core/lib/src/command.dart` durante Hito 1 y 2.
- Queda pendiente registrado en ROADMAP.md (Hito 3): migración a errores tipados, que reemplazará este ADR con uno nuevo.
- Disciplina mientras tanto: los mensajes de `DomainException` se escriben pensando en el usuario (la UI los muestra tal cual), no como mensajes de log.
