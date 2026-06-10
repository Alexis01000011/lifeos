# lifeos

App Android personal, modular y local-first: un hub de estadísticas de vida (gimnasio, ánimo, música, journaling...). Flutter + Drift + Riverpod, sobre Event Sourcing + CQRS. También: proyecto deliberado de aprendizaje de ingeniería.

**Empieza por aquí:** [docs/VISION.md](docs/VISION.md) (qué es y qué reglas tiene) → [docs/ROADMAP.md](docs/ROADMAP.md) (dónde vamos) → [docs/adr/](docs/adr/) (por qué decidimos lo que decidimos).

## Estructura

```
docs/
  VISION.md          norte del proyecto + contrato hub↔módulo
  ROADMAP.md         hitos hacia el MVP y después
  adr/               decisiones de arquitectura (ADRs numerados)
packages/
  core/              abstracciones ES+CQRS (puro Dart, cero deps)
  core_drift/        adaptador Drift/SQLite del event store (ADR-0006)
  gym/               (próximamente) primer módulo
  hub/               (próximamente) agregación entre módulos
app/                 (próximamente) shell Flutter que compone los módulos
```

## Protocolo de desarrollo

1. **Toda decisión de arquitectura se registra como ADR** (`docs/adr/`, usar TEMPLATE.md, numeración secuencial). Si en una sesión de diseño se eligió algo entre alternativas, hay ADR. Un ADR aceptado solo se cambia con otro ADR que lo reemplace.
2. **El roadmap se actualiza al cerrar cada hito.** Las sesiones de diseño terminan actualizando ROADMAP.md; si el código contradice VISION.md, se corrige uno de los dos explícitamente.
3. **Commits convencionales:** `feat(gym): ...`, `fix(core): ...`, `docs(adr): ...`, `test(...)`. Mensajes en español, imperativo.
4. **Rama `main` siempre verde:** los tests pasan antes de commitear. Trabajo experimental en ramas `exp/...`.
5. **La prueba ácida es sagrada:** ningún cambio puede romper "reset de proyecciones + replay = estado idéntico" (test automatizado desde Hito 1).
6. **Regla de fronteras:** ningún módulo importa a otro módulo (ver VISION.md, contrato hub↔módulo).
