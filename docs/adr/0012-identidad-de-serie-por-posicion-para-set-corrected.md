---
Status: Accepted
Date: 2026-06-11
---

# ADR-0012: identidad de serie por posición para SetCorrected

## Contexto

ADR-0010 difirió la corrección de series mal registradas porque necesita identidad de
serie, y esa decisión estaba amarrada a la de dropsets (que también la necesita). En
sesión 2026-06-11 se cerró: los dropsets se quedan como series consecutivas — el workaround
tiene sentido semántico y no vale introducir el concepto de "dropset" en el modelo. Eso
libera la decisión de identidad de serie para enfocarse solo en corrección.

La alternativa analizada fue asignar un UUID (`setId`) a cada `SetLogged`. Se descartó
porque los ~60 sets ya persistidos quedarían sin `setId` de todas formas (weak schema con
null), de modo que el beneficio de identidad explícita solo aplicaría a sets nuevos y la
corrección de históricos igual necesitaría un fallback a posición.

## Decisión

Usar `(workoutId, position)` como identidad de serie.

`SetCorrected` lleva `position`, `oldWeightKg`, `oldReps`, `weightKg` y `reps`. Los campos
`old*` hacen el evento autocontenido: el projector de historial calcula el delta de volumen
sin releer ninguna tabla.

**Por qué la invariante de posición se sostiene:** `RemoveLastSet` (ADR-0010) garantiza
que solo se puede eliminar la última serie de un workout en curso. Las posiciones de todas
las series excepto la última son inmutables una vez escritas. Un `SetCorrected` sobre
cualquier posición histórica siempre apunta a la misma fila.

El agregado Workout deja de trackear solo la última serie y pasa a mantener un mapa
`Map<int, ({double weightKg, int reps})>` de todas las series vivas. Esto simplifica
`removeLastSet` (ya no necesita los campos `_lastSetPosition/WeightKg/Reps`) y habilita
`correctSet` sin consultar proyecciones.

## Consecuencias positivas

- Sin migración: los sets existentes ya tienen `position` en la proyección.
- Evento autocontenido: el replay reproduce el estado correcto sin I/O adicional.
- `removeLastSet` se simplifica: lee `_sets[_setCount]` en lugar de campos separados.

## Consecuencias a vigilar

- Si en el futuro se permite eliminar series en posición arbitraria (no solo la última),
  esta decisión se revisa: las posiciones ya no serían inmutables. Lo reabre un ADR nuevo.
- Corrección del ejercicio de una serie no está soportada: `SetCorrected` solo cubre
  `weightKg` y `reps`. Si surgiera esa necesidad, la extensión natural es agregar
  `exercise`/`exerciseId` opcionales al evento con weak schema.
