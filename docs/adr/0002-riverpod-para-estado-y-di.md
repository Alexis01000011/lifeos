# ADR-0002: Riverpod para estado de UI e inyección de dependencias

- **Fecha:** 2026-06-09
- **Estado:** aceptada

## Contexto

Decisión de Fase 3: state management para Flutter. Candidatos: Riverpod y BLoC. La arquitectura ya fija dónde vive la lógica de negocio (agregados y command handlers, hexagonal + CQRS): la UI solo despacha comandos y renderiza proyecciones.

## Opciones consideradas

**Riverpod (elegida).** Pro: resuelve dos problemas a la vez — estado reactivo y DI compile-safe (los puertos hexagonales se cablean como providers, sobreescribibles en tests); `StreamProvider` encaja directo con los streams reactivos de Drift (proyección → stream → UI); modularidad natural (cada módulo expone sus providers). Con: no impone estructura (mitigado: la arquitectura ya la impone), curva de tipos de provider, historial de cambios de API entre mayores.

**BLoC.** Pro: patrón rígido evento→estado, `bloc_test`, muy presente en Flutter enterprise. Con: duplicaría el patrón que ya vive en el dominio creando dos significados de "evento" (UI vs. dominio) — confusión grave en un proyecto cuyo corazón es Event Sourcing; boilerplate alto por pantalla; no resuelve DI (requeriría get_it aparte).

## Decisión

Riverpod. Argumento decisivo: BLoC vende disciplina que ya compramos en la capa de dominio, y aun así dejaría el problema de DI sin resolver; Riverpod cubre ambos.

## Consecuencias

- Riverpod es también el contenedor de DI del proyecto: no se agrega get_it ni similar.
- La UI se mantiene delgada: providers que exponen streams de proyecciones y despachan comandos. Si aparece lógica de negocio en un provider, está en el lugar equivocado.
- Cada módulo expone sus providers; la app shell los compone.
