---
version: alpha
name: lifeos
platform: Flutter 3.x · Android (Material 3) · target: Samsung A71 (393dp, AMOLED)
description: >-
  Sistema de diseño para lifeos — app Android personal de telemetría de vida.
  Tokens y reglas de UI para mantener una interfaz de instrumento de precisión:
  datos crudos sin suavizar, fricción mínima, legible de madrugada y bajo el sol.
  Legible por personas y agentes de IA.

# ─────────────────────────────────────────────────────────────────────────────
# TOKENS — fuente de verdad máquina-legible
# ─────────────────────────────────────────────────────────────────────────────

colors:
  # ─── Superficies (Dark-first, OLED-friendly) ─────────────────────────────
  # El A71 tiene pantalla AMOLED. Near-black (#0D1117) ≠ pitch-black (#000000):
  # evita halos y PWM en brillo bajo; en AMOLED real apaga ~98% de píxeles.
  bg:                "#0D1117"   # fondo raíz de la app
  surface:           "#161B22"   # tarjetas, paneles, drawers
  surface-raised:    "#21262D"   # tarjetas elevadas, dialogs, bottom sheets
  surface-tint:      "#2A2F38"   # pressed/hover state, dividers

  # ─── Primario: Teal eléctrico ─────────────────────────────────────────────
  # Por qué teal: evoca instrumentos de precisión (monitores, GPS, wearables).
  # No es el azul de Material por defecto. No es el morado de apps de IA.
  # Contraste sobre bg: 7.1:1 ✅ AAA · sobre surface: 6.3:1 ✅ AAA
  primary:           "#39D2C0"   # FAB, botones CTA, icono activo, cifras clave
  primary-dim:       "#1EA896"   # pressed state del primario
  primary-container: "#0D3330"   # fondo de chip activo, badge de módulo encendido
  on-primary:        "#0D1117"   # texto/icono sobre teal — OSCURO, no blanco
  on-primary-container: "#4FE5D3"

  # ─── Secundario: Ámbar cálido ─────────────────────────────────────────────
  # Complementa el teal sin competir. PRs, rachas, tendencia positiva.
  # Contraste sobre surface: 5.4:1 ✅ AA
  secondary:         "#F8A051"   # PRs del gym, racha de días, destaque de logro
  secondary-dim:     "#C47A30"   # pressed state del secundario
  secondary-container: "#3D2000"
  on-secondary:      "#0D1117"

  # ─── Texto ────────────────────────────────────────────────────────────────
  text:              "#E6EDF3"   # cuerpo principal — no blanco puro (reduce fatiga OLED)
  text-muted:        "#9DA7B3"   # metadatos, labels secundarios — 7.7:1 sobre bg, 6.2:1 sobre surface-raised ✅ AA
  text-subtle:       "#484F58"   # placeholders, texto deshabilitado
  on-surface:        "#E6EDF3"   # alias de text para Material ColorScheme

  # ─── Bordes ───────────────────────────────────────────────────────────────
  border:            "#30363D"   # borde estándar de tarjetas e inputs
  border-focus:      "#39D2C0"   # borde de input con foco — mismo que primary

  # ─── Semánticos ───────────────────────────────────────────────────────────
  success:           "#3FB950"   # confirmación, registro exitoso
  success-container: "#0D2E12"
  error:             "#F85149"   # DomainException, errores, datos críticos
  error-container:   "#2E0D0D"
  warning:           "#D29922"   # datos incompletos, avisos
  warning-container: "#2E2200"
  info:              "#58A6FF"   # tooltips, referencia histórica

  # ─── Paleta de series (hasta 4 en gráficas simultáneas) ──────────────────
  chart-1: "#39D2C0"   # = primary — serie del módulo activo
  chart-2: "#F8A051"   # = secondary — serie cruzada
  chart-3: "#58A6FF"   # azul info — tercera serie
  chart-4: "#D29922"   # amarillo — cuarta serie

typography:
  # DM Sans: geométrica humanista, alta legibilidad en pantallas pequeñas,
  # no monótona como Roboto ni tan omnipresente como Inter.
  # DM Mono: compañera numérica — cifras alineadas, legibles sin esfuerzo.
  family-sans: "DM Sans, system-ui, sans-serif"
  family-mono: "DM Mono, Roboto Mono, monospace"

  # Escala (valores en sp, equivale a dp para texto en Flutter)
  # Mapeo a Flutter TextTheme (Material 3):
  displaySmall:   { size: 34, weight: 700, height: 1.1,  family: mono }  # cifra hero en hub
  headlineMedium: { size: 22, weight: 600, height: 1.25, family: sans }  # título de pantalla
  titleLarge:     { size: 18, weight: 600, height: 1.3,  family: sans }  # AppBar, sección
  titleMedium:    { size: 15, weight: 600, height: 1.4,  family: sans }  # nombre de tarjeta
  bodyLarge:      { size: 16, weight: 400, height: 1.5,  family: sans }  # texto de cuerpo
  bodyMedium:     { size: 14, weight: 400, height: 1.5,  family: sans }  # texto secundario
  labelLarge:     { size: 14, weight: 600, height: 1.2,  family: sans }  # botones, chips
  labelSmall:     { size: 11, weight: 500, height: 1.2,  family: sans, letterSpacing: 0.06em }  # unidades, captions

  # Variante numérica (usada directamente en widgets de datos)
  numeric-hero:   { size: 48, weight: 700, family: mono }  # cifra enorme (total del hub)
  numeric-large:  { size: 32, weight: 700, family: mono }  # cifra grande (PR del gym)
  numeric-medium: { size: 20, weight: 500, family: mono }  # cifra de tarjeta
  numeric-small:  { size: 14, weight: 500, family: mono }  # tabla, lista de series

spacing:
  # Base 4dp — escala Material 3
  xs:   4
  sm:   8
  md:   16
  lg:   24
  xl:   32
  "2xl": 48
  "3xl": 64

shapes:
  # BorderRadius.circular(r) — Flutter
  xs:   6     # chips de tag pequeños
  sm:   10    # inputs, chips activos
  md:   14    # botones, tarjetas compactas
  lg:   18    # tarjetas de módulo en el hub
  xl:   24    # bottom sheets, dialogs grandes
  full: 999   # FAB, pills, avatares

motion:
  # Flutter Duration(milliseconds: N)
  instant:  100   # ripple, scale on press
  fast:     180   # chip toggle, feedback de estado
  medium:   280   # SharedAxisTransition entre pantallas
  slow:     420   # animaciones de entrada de datos en hub

accessibility:
  touch-min: 48   # dp — toque mínimo Material 3 (GestureDetector hitTestBehavior)
  contrast-body: 4.5   # ratio mínimo WCAG AA para texto normal
  contrast-large: 3.0  # ratio mínimo WCAG AA para texto ≥ 18sp o 14sp bold
---

# DESIGN.md — lifeos

> **Creado:** 2026-06-11 · **Estado:** `alpha` · **Formato:** Google DESIGN.md (front-matter de tokens) + reglas de diseño verificables
>
> Este documento **no es código**: es el plano que guía toda implementación de UI. Antes de escribir cualquier widget, se consulta este doc. Si una pantalla contradice algo de aquí, está mal diseñada o el diseño necesita actualizarse con justificación explícita.

## Cómo usar este archivo (personas y agentes)

Este archivo tiene dos capas:

1. **Front-matter YAML** (arriba): los *tokens* — valores canónicos de color, tipografía, espaciado, etc. Fuente de verdad para `ThemeData`.
2. **Cuerpo Markdown** (abajo): el *porqué*, recetas de componentes, patrones por módulo, y las **reglas verificables** con ID.

**Para un agente que genere o revise Flutter UI, el contrato es:**

| | Regla |
|---|---|
| ✅ **Siempre** | Tokens del front-matter. Nunca un valor hardcoded de color, tamaño o espaciado. |
| ⚠️ **Consulta primero** | Si necesitas un token que no existe, propónlo aquí antes de inventar un valor. |
| 🚫 **Nunca** | `Color(0xFF...)` inline, `const Color(Colors.blue)`, padding arbitrario, `TextStyle` fuera de `Theme.of(context)`, widgets decorativos vacíos de información. |

---

## 1. Identidad visual: El Instrumento

lifeos no es una app de bienestar con gradientes de aurora y emojis de sol. Es un **instrumento de medición personal** — la diferencia entre un monitor de frecuencia cardíaca y una app de meditación.

**El principio visual central:** los datos se muestran con precisión y sin adorno. Un número malo se muestra como número malo. Las gráficas no tienen animaciones de "celebración". Las métricas incómodas no se redondean.

Esto se traduce en cinco decisiones estéticas no negociables:

1. **Dark-first.** La app se usa de madrugada (log de sueño), bajo el sol (gym) y de noche (calificación del día). Dark mode elimina el parpadeo matutino, extiende la batería del A71 (AMOLED), y hace que los datos en teal destaquen sobre el fondo oscuro como un display de instrumento.

2. **Teal eléctrico como único color de acción.** Un color de acción, claro e inequívoco. No compite con los datos. El ámbar complementa (logros, PRs) sin usurpar la acción.

3. **Jerarquía por tipografía, no por decoración.** Las cifras importantes son grandes y en DM Mono. Los títulos de sección son semibold. El cuerpo es regular. Sin iconos decorativos, sin ilustraciones de onboarding, sin mascota.

4. **Datos crudos, siempre.** Las series temporales muestran lo que hay, no una versión suavizada. Si hay un hueco de datos (días sin registrar), el hueco es visible. Si el sueño fue malo, el número es rojo. Un "score" bajo en el día se muestra bajo.

5. **Fricción visual mínima.** Cero elementos de chrome que no sirvan para navegar o para entender datos. Cada elemento en pantalla gana su lugar.

---

## 2. Colors

### Paleta completa y cuándo usar cada color

| Token | Hex | Contraste sobre bg | Uso principal |
|---|---|---|---|
| `primary` | `#39D2C0` | 7.1:1 ✅ AAA | FAB, botones CTA, icono de nav activo, valor de dato clave |
| `primary-dim` | `#1EA896` | 4.8:1 ✅ AA | Estado pressed del primario |
| `secondary` | `#F8A051` | 5.4:1 ✅ AA | PR del gym, racha de días, tendencia positiva |
| `text` | `#E6EDF3` | 13.5:1 ✅ AAA | Cuerpo, cifras |
| `text-muted` | `#9DA7B3` | 7.7:1 ✅ AAA | Labels secundarios, unidades, metadatos |
| `text-subtle` | `#484F58` | 2.3:1 ❌ | **Solo** placeholders y texto deshabilitado (nunca contenido real) |
| `success` | `#3FB950` | 5.2:1 ✅ AA | Registro exitoso, tendencia positiva |
| `error` | `#F85149` | 5.0:1 ✅ AA | Errores, excepciones, dato crítico |
| `warning` | `#D29922` | 4.6:1 ✅ AA | Datos incompletos, avisos no críticos |
| `info` | `#58A6FF` | 5.8:1 ✅ AA | Datos de referencia, tooltips |

### Reglas de color

- **El color de acción es teal. Uno solo.** No uses azul, verde o lila para CTAs o estados de selección. El ámbar es acento, no acción primaria.
- **Los datos usan el color semántico.** Una nota del día alta → `success`. Una nota baja → no se penaliza con `error` (solo es bajo). Error es para fallos del sistema, no para "datos malos del usuario".
- **El color nunca es el único portador de información.** Un error lleva icono + texto + color. Una racha lleva ícono + número + color. Ver `[A11Y-003]`.
- **No existe un modo claro.** Dark-first no significa "solo oscuro para siempre", pero v1 no implementa modo claro. Si en el futuro se agrega, los tokens del front-matter son la única fuente que cambia — el código no hardcodea ningún `Color(...)` directamente.

---

## 3. Typography

### Por qué DM Sans + DM Mono

- **DM Sans**: humanista geométrica. Legible en 11sp, no fría como Roboto, no tan omnipresente como Inter. Diseñada para interfaces de tamaño reducido.
- **DM Mono**: compañera de DM Sans. Para todas las cifras de datos — el ancho fijo evita que los números "brinquen" al actualizar una lista de métricas.
- **Nunca dos familias de texto mezcladas**: DM Sans para todo el chrome; DM Mono para todos los valores numéricos. Nada más.

### Escala y uso

| Token | sp | Peso | Uso |
|---|---|---|---|
| `numeric-hero` | 48 | 700 mono | Cifra principal del hub (ej. "7 entrenamientos") |
| `numeric-large` | 32 | 700 mono | PR en tarjeta de gym, TST de sueño |
| `displaySmall` | 34 | 700 mono | Usado por los widgets de cifra hero |
| `headlineMedium` | 22 | 600 sans | Título de pantalla (AppBar, nombre de módulo) |
| `titleLarge` | 18 | 600 sans | Secciones dentro de una pantalla |
| `titleMedium` | 15 | 600 sans | Nombre de tarjeta, label fuerte |
| `bodyLarge` | 16 | 400 sans | Texto de cuerpo, descripciones |
| `bodyMedium` | 14 | 400 sans | Listas, texto secundario |
| `labelLarge` | 14 | 600 sans | Texto de botones, chips accionables |
| `labelSmall` | 11 | 500 sans | Unidades (kg, min), captions, fechas |

### Reglas de tipografía

- **Texto de cuerpo ≥ 16sp.** `bodyMedium` (14sp) solo para listas densas y metadata; nunca para instrucciones o descripciones que el usuario necesita leer.
- **Toda cifra de dato usa DM Mono.** Un peso en kg, una nota del día, minutos de sueño, un PR: DM Mono siempre. El chrome (labels, títulos) es DM Sans.
- **Peso para jerarquía, tamaño para importancia.** No usar colores para diferenciar niveles de texto dentro de una tarjeta; usar peso (600 vs 400) o tamaño.
- **No `fontStyle: italic` en datos.** Las cursivas en una pantalla de datos compiten con la legibilidad. Reservadas para casos excepcionales de UI (ej. texto de cita).

---

## 4. Spacing & Layout

### Rejilla 4dp

Toda medida de padding, margin, gap o tamaño es múltiplo de 4. No existe `padding: 5`, `margin: 7`, `SizedBox(height: 13)`.

```
xs=4  · sm=8  · md=16  · lg=24  · xl=32  · 2xl=48
```

### Layout de pantalla

El A71 tiene 393dp de ancho. No hay breakpoints en la versión móvil. Todas las pantallas son de columna única.

```
┌──────────────────────────────────┐  ← 393dp ancho total
│  padding horizontal: md (16dp)   │
│  ┌────────────────────────────┐  │
│  │     contenido principal    │  │
│  │     max 361dp de ancho     │  │
│  └────────────────────────────┘  │
│  padding horizontal: md (16dp)   │
└──────────────────────────────────┘
```

- **Padding horizontal de pantalla:** `md` (16dp) en ambos lados. Las tarjetas van de borde a borde del área de contenido.
- **Gap entre tarjetas:** `sm` (8dp) para tarjetas del mismo grupo, `md` (16dp) entre grupos/secciones.
- **Padding interno de tarjeta:** `md` (16dp) horizontal, `md` (16dp) vertical para tarjetas normales; `lg` (24dp) para tarjetas de hub que son el punto focal.
- **Área táctil mínima:** 48dp × 48dp para cualquier elemento interactivo. Ver `[A11Y-001]`.

---

## 5. Elevation & Shapes

### Elevation (Material 3 en modo oscuro = tint de color)

En Material 3 oscuro, la elevación se expresa con un tint de color sobre la superficie, no con sombra. Flutter lo gestiona automáticamente con `ColorScheme.surfaceTint`.

| Nivel | Uso | Color aproximado |
|---|---|---|
| 0 (`bg`) | Fondo de pantalla | `#0D1117` |
| 1 (`surface`) | Tarjetas de contenido, paneles | `#161B22` |
| 2 (`surface-raised`) | Bottom sheets, dialogs, drawers | `#21262D` |
| FAB overlay | El FAB flota sobre todo | `primary` con sombra sutil |

**Regla:** nunca uses `BoxDecoration` con `boxShadow` explícito en tarjetas. La elevación es responsabilidad de `Card`, `BottomSheet`, `Dialog` con el `elevation` correcto del theme. Las sombras no existen en esta UI.

### Shapes (Border Radius)

| Token | dp | Uso |
|---|---|---|
| `xs` | 6 | Tags pequeños, chips compactos |
| `sm` | 10 | Inputs de formulario, chips activos |
| `md` | 14 | Botones, tarjetas de lista compactas |
| `lg` | 18 | Tarjetas del hub, header de bottom sheets |
| `xl` | 24 | Modales completos, bottom sheets grandes |
| `full` | 999 | FAB, píldoras, chips de tag redondeados |

**Regla:** no mezclar radios. Una tarjeta del hub tiene `lg` (18dp) en todas las esquinas. Un chip de tag tiene `full`. Un botón principal tiene `md`. La consistencia en radios es lo que hace que la app "sienta" uniforme.

---

## 6. ThemeData raíz (Flutter)

El `ThemeData` se configura una sola vez en el `app/lib/main.dart` (o en el composition root de Riverpod). Ningún widget define colores o estilos de texto fuera del theme.

```dart
// Pseudocódigo — implementación real en un ADR cuando se aborde
ThemeData lifeosTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF39D2C0),
    onPrimary: Color(0xFF0D1117),
    primaryContainer: Color(0xFF0D3330),
    onPrimaryContainer: Color(0xFF4FE5D3),
    secondary: Color(0xFFF8A051),
    onSecondary: Color(0xFF0D1117),
    secondaryContainer: Color(0xFF3D2000),
    surface: Color(0xFF161B22),
    onSurface: Color(0xFFE6EDF3),
    surfaceContainerHighest: Color(0xFF21262D),
    error: Color(0xFFF85149),
    onError: Color(0xFF0D1117),
    background: Color(0xFF0D1117), // deprecated M3 pero necesario compat
    onBackground: Color(0xFFE6EDF3),
  ),
  textTheme: TextTheme(
    // DM Sans en todas las variantes sans; DM Mono en displaySmall
    // La implementación asigna GoogleFonts.dmSans() y GoogleFonts.dmMono()
  ),
  // CardTheme, FilledButtonTheme, InputDecorationTheme, NavigationBarTheme,
  // BottomSheetTheme, SnackBarTheme — todos definidos aquí, no en cada widget
);
```

**Regla crítica:** `Theme.of(context).colorScheme.primary` — nunca `Color(0xFF39D2C0)` hardcodeado en un widget. Si el theme cambia, los widgets heredan el cambio sin tocarlos.

---

## 7. Components

Recetas canónicas de los componentes de la app. Cada receta describe el widget Flutter, los tokens que usa y las variantes permitidas.

### 7.1 Hub Card (Tarjeta de módulo en la pantalla principal)

Es la unidad visual más importante de la app. Cada módulo activo registra una tarjeta aquí.

```
┌────────────────────────────────┐  ← Card, elevation 1, radius lg (18dp)
│ ICONO  Gym                  ›  │  ← titleMedium + icon, color text
│                                │
│     ████ 7                     │  ← numeric-hero, color primary
│     entrenamientos             │  ← labelSmall, color text-muted
│     esta semana                │
│                                │
│ ─────────────────────────────  │  ← Divider, color border
│ ▲ +12 % vs semana anterior     │  ← labelSmall, color success/error según delta
└────────────────────────────────┘
  padding: lg (24dp) horizontal, md (16dp) vertical
```

- **Tap en la tarjeta** → navega al módulo. El área táctil es la tarjeta completa.
- **La cifra hero usa `numeric-hero` (DM Mono 48sp).** Es lo primero que el ojo lee.
- **Delta de tendencia:** usa `success` (verde) para mejora, `error` (rojo) para desmejora, `text-muted` para neutro. El icono acompaña al color.
- **Si no hay datos aún** (módulo recién instalado): la cifra muestra `—` en `text-subtle`, sin inventar ceros.

### 7.2 Stat Chip (cifra pequeña en contexto)

Para estadísticas secundarias dentro de pantallas de módulo.

```
┌──────────────────┐  ← container, radius md (14dp), bg surface-raised
│  📊  415 min     │  ← labelLarge (DM Mono) + labelSmall para unidad
│  Sueño total     │  ← bodyMedium, color text-muted
└──────────────────┘
  padding: sm (8dp) vertical, md (16dp) horizontal
```

### 7.3 Botón primario (FilledButton)

```
┌─────────────────────────────┐  ← FilledButton, bg primary, radius md (14dp)
│       Completar entreno     │  ← labelLarge, color on-primary
└─────────────────────────────┘
  height mínima: 48dp · padding horizontal: lg (24dp)
```

- **Estado pressed:** `primary-dim` (`#1EA896`). No se usan opacidades — se usa el token `primary-dim`.
- **Estado disabled:** `text-subtle` sobre `surface-tint`. Sin animación especial.
- **No existe botón primario con ícono** como patrón habitual. Los FABs tienen ícono. Los botones de texto largo no.

### 7.4 Botón secundario (OutlinedButton)

```
┌─────────────────────────────┐  ← OutlinedButton, border `border`, radius md
│         Cancelar            │  ← labelLarge, color text
└─────────────────────────────┘
```

### 7.5 FAB (Acción de captura principal)

El FAB es **el punto de entrada a toda captura**. En la pantalla principal y en cada módulo, el FAB es el único elemento de acción flotante.

- Color: `primary` (#39D2C0). Ícono: `on-primary` (#0D1117).
- Tamaño: FAB estándar (56dp × 56dp) en la esquina inferior derecha.
- **No existe Extended FAB en v1.** La pantalla de captura se abre con un ícono solo. El label del FAB es fricción.
- Radius: `full` (999dp — círculo).

### 7.6 Input de formulario

```
┌─────────────────────────────────┐  ← border radius sm (10dp)
│ Peso (kg)                       │  ← label sobre el input (FloatingActionLabel)
│ 85                              │  ← bodyLarge, color text
│─────────────────────────────────│  ← underline cuando tiene foco: color primary
└─────────────────────────────────┘
```

- **Siempre con label visible.** El placeholder desaparece al escribir — nunca es la única etiqueta.
- **El borde de foco es `border-focus` (teal).** No Material blue por defecto.
- **Inputs numéricos** (peso, reps, nota del día): `keyboardType: TextInputType.number`, alineación de texto centrada o derecha, font `numeric-medium`.

### 7.7 Tag Chip (para módulo `days` y módulo `affect`)

```
 ┌──────────────┐  ┌────────────────┐
 │  ● ejercicio │  │  + socializar  │  ← chips de filtro/selección
 └──────────────┘  └────────────────┘
   activo: bg primary-container, text on-primary-container
   inactivo: bg surface-tint, text text-muted
   radius: full (pill) · padding: xs (4dp) vertical, sm (8dp) horizontal · height: 32dp
```

- **Tap = toggle.** El estado visual es suficiente feedback; sin SnackBar por cada toggle.
- **Los tags fluyen en un `Wrap` widget**, no en un `Row` con scroll horizontal.

### 7.8 Slider de nota (módulo `days`)

El único slider de la app. Para la calificación 0–10 del día.

- `Slider` de Flutter con `activeColor: primary`, `thumbColor: primary`.
- Muestra el valor actual en un `Tooltip` sobre el thumb mientras se arrastra.
- Debajo del slider: etiquetas extremas `0` (left) y `10` (right) en `labelSmall`, color `text-muted`.
- **El slider es de resolución entera (0–10),** no decimal. Usar `divisions: 10`.

### 7.9 BottomSheet de captura rápida

El patrón de entrada de datos más importante. Se usa para: calificar el día, log de calidad de sueño, registro rápido de set en gym.

```
┌──────────────────────────────────────┐
│  ████ [drag handle, 32dp wide]       │
│                                      │  ← bg surface-raised, radius xl (24dp)
│  Calificar hoy                       │  ← titleLarge, padding top md
│                                      │
│  [contenido del formulario]          │
│                                      │
│  [FilledButton primario completo]    │
│                                      │  ← padding bottom: xl (32dp) + safe area
└──────────────────────────────────────┘
```

- **El drag handle es obligatorio** (altura 4dp, ancho 32dp, bg `border`, radius `full`). Es la señal de que la hoja se puede cerrar arrastrando.
- **El botón de acción principal va abajo**, siempre visible sin scroll (si el formulario crece más de ~5 campos, revisar si el diseño necesita dividirse).
- **No existe un botón de cancelar explícito.** Arrastrar hacia abajo o tocar fuera cierra el sheet.

### 7.10 Barra de navegación inferior (NavigationBar)

```
┌─────────────────────────────────────┐
│  🏠 Hub  │  🏋️ Gym  │  📅 Días  │  ...  │
│  [act.]  │         │           │       │  ← activo: icono filled + label visible
└─────────────────────────────────────┘
  bg: surface · height: 80dp · indicador activo: primary-container
```

- **Solo los módulos activos aparecen en la barra.** Un módulo no empezado no ocupa un slot.
- **Íconos outlined** en estado inactivo, **filled** en estado activo. Material 3 estándar.
- **Label siempre visible** (no solo en activo). `NavigationBar` de Material 3, no `BottomNavigationBar` legacy.
- **Máximo 4 destinos.** Si hubiera más módulos activos, se considera un drawer o un tab adicional. En el MVP con gym únicamente (o gym + days) son 2–3 destinos.

### 7.11 SnackBar (feedback de acciones)

- **Solo para confirmaciones y errores no bloqueantes.** No para navegar, no para pedir confirmación.
- Bg: `surface-raised` · texto: `text` · acción opcional en `primary`.
- Duración: 3 segundos para confirmaciones, 5 segundos para errores.
- **Los errores críticos (DomainException) van en un `AlertDialog`**, no en un SnackBar. El SnackBar es para "entrenamiento guardado", no para "no puedes hacer eso porque...".

---

## 8. Patrones por módulo

Cada módulo tiene sus propias pantallas, pero todos siguen los mismos patrones de layout y los mismos componentes. Aquí se documenta lo que es específico de cada uno.

### 8.1 Hub (pantalla principal)

```
AppBar:  "lifeos"  [fecha de hoy, text-muted, labelSmall]
───────────────────────────────────────────────────────
Scroll vertical de Hub Cards (una por módulo activo)
  · Gym card: "7 entrenamientos esta semana"
  · Days card: "Nota de hoy: 7"  (o "sin calificar")
  · Sleep card: "6h 55m · calidad 4/5"
  · ...
───────────────────────────────────────────────────────
[sección "Correlaciones" cuando haya datos suficientes]
───────────────────────────────────────────────────────
FAB (➕): no aplica en hub — la acción es navegar al módulo
```

- **Si el hub tiene un solo módulo activo,** la Hub Card ocupa más espacio vertical — no hay un grid de 2 columnas. La jerarquía vertical es correcta para esta etapa.
- **La correlación estrella (sueño → ánimo día N+1)** aparece como una card especial de hub cuando hay ≥14 días de datos en ambos módulos. No aparece vacía.

### 8.2 Gym (pantalla de Entreno activo)

```
AppBar: "Entreno en curso"  [HH:MM de duración · text-muted]
───────────────────────────────────────────────────────
[Las últimas 3 series del ejercicio activo — mini-lista]
  · Ejercicio: [nombre] [picker]
  · Serie  | Reps | Peso kg   ← labelSmall headers
  · 1      |  10  | 80.0      ← numeric-small (DM Mono)
  · 2      |  8   | 82.5
  · 3      |  6   | 85.0
───────────────────────────────────────────────────────
[Formulario de nueva serie — siempre visible]
  [Reps] [Peso] [kg/lb toggle]  [⊕ Agregar]
───────────────────────────────────────────────────────
[Completar entreno — FilledButton abajo]
```

- **Un ejercicio a la vez en foco.** El cambio de ejercicio es un tap en el nombre (abre picker de ejercicios).
- **El teclado numérico se levanta** al tocar el campo de reps/peso. El formulario sube con él. No se usa `SingleChildScrollView` sin `resizeToAvoidBottomInset: true`.
- **Dropsets:** en v1 se registran como series consecutivas con descanso ≤ 30 s (campo de descanso; la semántica es workaround documentado hasta que haya un evento específico).

### 8.3 Days (calificar hoy)

```
BottomSheet de captura (desde FAB o hub card):
────────────────────────────────────────────
 ¿Cómo fue tu día?        [fecha — labelSmall text-muted]
 
 [Slider 0–10, divisiones enteras]
              7
    0                    10
 
 [Wrap de Tag Chips: ejercicio / trabajo / social / ...]
 
 [FilledButton "Guardar"]
────────────────────────────────────────────
```

- **< 5 segundos de captura** es el objetivo. El slider + 0–3 tags es el flujo feliz.
- **Si el día ya fue calificado:** el BottomSheet pre-carga los valores actuales. El botón dice "Actualizar" en vez de "Guardar". El evento emitido es `DayRatingAmended`.

### 8.4 Sleep (calidad de sueño matutina)

```
BottomSheet de captura (desde notificación o hub card al abrir la app):
────────────────────────────────────────────
 Anoche                   [fecha — labelSmall]
 
 Samsung Health importó:  ← bodyMedium, text-muted
 6h 55m · 01:12 → 08:07  ← numeric-medium, DM Mono
 
 ¿Cómo lo sentiste?  [Likert 1–5 horizontal]
  😴  1  2  3  4  5  ☀️
      ○  ○  ●  ○  ○
 
 [FilledButton "Guardar"]
────────────────────────────────────────────
```

- **El 1 toque es la calidad subjetiva.** Los tiempos vienen de Health Connect — se muestran como referencia, no se editan en el flujo feliz.
- **Si Health Connect no tiene datos:** el formulario manual (CSD 9 ítems) se abre como pantalla completa, no como bottom sheet. Más fricción aceptada porque es el fallback.

### 8.5 Affect (momentary sampling)

*(Hito 6 — se documenta el patrón para no reinventarlo cuando llegue)*

```
BottomSheet ESM (semi-aleatorio, 3–5 veces al día):
────────────────────────────────────────────
 ¿Cómo te sientes ahora?
 
 [Grid 9×9 del Affect Grid]
   ← Displacer         Placentero →
   ↑ Alta activación
   ↓ Baja activación
 
 [tap en el grid = captura + cierra automáticamente]
────────────────────────────────────────────
```

- **Un solo toque en el grid cierra el sheet.** Sin botón de guardar. La fricción es: abrir la app + tocar.
- **El Affect Grid es un `GestureDetector` sobre un `CustomPaint`.** No es una cuadrícula de botones.

---

## 9. Navegación

### Patrón general

```
NavigationBar inferior → destino de módulo activo
  Dentro de cada módulo:
    AppBar con título + botón atrás si es pantalla de profundidad
    FAB para captura nueva
    tap en item de lista → pantalla de detalle
```

### Transiciones

- **Entre módulos (NavigationBar):** `FadeTransition` o sin transición. Los módulos son peers — no hay jerarquía.
- **Dentro de un módulo (push/pop):** `SharedAxisTransition` horizontal (Material 3 — slide suave, no el push abrupto por defecto de Flutter).
- **BottomSheet de captura:** la animación estándar de `showModalBottomSheet` con `isScrollControlled: true`.
- **Nunca `PageRouteBuilder` con `transitionDuration: Duration.zero`.** Las transiciones a 0ms desorientan. Si parece lento, ajustar la duración a `fast` (180ms), no eliminarla.

### Deep links y estado de navegación

En v1 no hay deep links externos. La app siempre abre en el hub. El estado de la sesión de entreno (workout en curso) persiste en una proyección, no en el estado de navegación.

---

## 10. Visualización de datos

Las gráficas son el output más importante del hub. Reglas específicas para que no se conviertan en decoración.

### Serie temporal (eje de tiempo horizontal)

```
8 ─────────────────────────── primary (#39D2C0), strokeWidth 2dp
   ·   ·   ·
6 ·   · · ·   ·   ·  ─ ─ ─  texto-muted para referencia histórica
   ·       ·   · ·
4 ──────────────────── eje X: labelSmall, color text-subtle
   L   M   X   J   V   S   D
```

- **Solo la línea y los puntos de dato.** Sin área de relleno (obscurece datos superpuestos), sin gradiente.
- **Un punto de dato faltante = brecha en la línea.** No se interpola. El hueco es información.
- **Ejes:** mínimo información necesaria (fechas, valor máx/mín). Sin grid completa — una sola línea de referencia horizontal si ayuda a escala.
- **Dos series en la misma gráfica** (correlación) usan `chart-1` y `chart-2`. Nunca más de 2 en la misma área sin un toggle de visibilidad.
- **Librería recomendada:** `fl_chart` (flexible, no opinada). Alternativa `syncfusion_flutter_charts` si se necesita más poder. **No** usar librerías que fuercen un estilo de chart de colores pasteles.

### Densidad de distribución (módulo `affect`)

Para la distribución del afecto (Fleeson 2001), una gráfica de violín o histograma suave, no un diagrama de caja-bigotes. El `fl_chart` puede hacer un `BarChart` con interpolación spline que se aproxima a un violín.

---

## 11. Accesibilidad

lifeos tiene un solo usuario. Eso no es licencia para ignorar accesibilidad — es un riesgo diferente: si la app no es legible en condiciones extremas (gym con luz intensa, cama en la madrugada), no se usa.

- **Contraste mínimo en texto:** 4.5:1 para texto ≤ 17sp (AA). Todo token de `text` y `text-muted` pasa este threshold sobre `surface`. `text-subtle` NO pasa — solo para placeholders deshabilitados.
- **Áreas táctiles ≥ 48dp × 48dp.** Un chip de tag de 32dp de alto tiene una zona transparente de 8dp alrededor para alcanzar los 48dp. Usar `GestureDetector` con `behavior: HitTestBehavior.translucent` o `Padding` alrededor del widget visual.
- **El foco del teclado físico** (si algún día se conecta un teclado Bluetooth) sigue el orden lógico. No `FocusNode` desordenados.
- **Semántica:** `Semantics` o `ExcludeSemantics` en los elementos decorativos. Los iconos de datos llevan `semanticsLabel`.
- **Modo de alto contraste del sistema:** no se implementa una variante adicional, pero los tokens ya cumplen AA en modo estándar, que es lo mínimo requerido.

---

## 12. Do's & Don'ts

| ✅ Sí | 🚫 No |
|---|---|
| Tokens del front-matter para todo color/tamaño | `Color(0xFF...)`, `const Color(Colors.blue)`, hex inline |
| DM Mono para toda cifra de dato | Cifras de dato en DM Sans o en Roboto heredado |
| FAB como única acción flotante | Múltiples FABs o botones flotantes |
| Datos crudos, sin suavizar resultados negativos | Mostrar emojis de celebración por registrar datos |
| `Theme.of(context)` en todos los widgets | `ThemeData` reinventado dentro de un widget |
| Brecha en la gráfica cuando faltan datos | Interpolar o rellenar datos faltantes |
| Feedback visual + texto en errores | Solo color para indicar estado de error |
| BottomSheet para capturas rápidas | Pantalla completa para formularios de 1–3 campos |
| `NavigationBar` Material 3 | `BottomNavigationBar` legacy o tabs en AppBar |
| Dark theme siempre (v1) | Modo claro sin actualizar el ThemeData primero |
| `SharedAxisTransition` para navegación | Transiciones custom complejas o sin transición |
| Iconos de Material Symbols (outlined/filled) | Iconos de otras librerías mezclados con Material |
| Hueco visible en gráfica por dato faltante | Línea interpolada que inventa datos |
| Módulo no started = no aparece en NavigationBar | Módulos sin datos ocupando espacio visual |

---

## 13. Reglas verificables

Formato: `[ID] severidad — enunciado`. Aplicar en toda revisión de código Flutter.

```
[COLOR-001] error  — MUST: todo color proviene de ColorScheme o del token del ThemeData.
            never: Color(0xFFXXXXXX) directamente en un widget.

[COLOR-002] error  — MUST NOT: Colors.* hardcodeado en widgets (excepto Colors.transparent).
            forbid: Colors\.(?!transparent)\w+

[COLOR-003] error  — MUST NOT: modo claro sin ADR. ThemeData.light sin aprobación.
            forbid: brightness: Brightness\.light

[TYPE-001]  error  — MUST: texto de cuerpo usa Theme.of(context).textTheme.*
            never: TextStyle(fontSize: X, fontWeight: Y) sin referencia al theme.

[TYPE-002]  error  — MUST NOT: familia de fuente hardcodeada en widget.
            forbid: fontFamily:\s*['"](?!DM\s(?:Sans|Mono))

[TYPE-003]  warn   — SHOULD: cifras de dato usan textTheme.displaySmall o variante numeric-*.
            Señal de alerta: cifra de dato con fontFamily DM Sans.

[SPACE-001] error  — MUST: todo valor de padding/margin/gap es múltiplo de 4.
            forbid: EdgeInsets.*\b(1|2|3|5|6|7|9|10|11|13|14|15|17|18|19|21)\b

[SPACE-002] error  — MUST NOT: SizedBox con alto o ancho que no sea múltiplo de 4.

[SHAPE-001] error  — MUST: BorderRadius usa solo los tokens de shapes.
            forbid: BorderRadius\.circular\((?!6|10|14|18|24|999)\d

[A11Y-001]  error  — MUST: área táctil ≥ 48×48dp en todo widget interactivo.

[A11Y-002]  error  — MUST: errores y estados llevan texto + icono, no solo color.

[A11Y-003]  warn   — SHOULD: Semantics() en gráficas y elementos custom.

[DATA-001]  error  — MUST NOT: interpolación de datos faltantes en gráficas.
            Un dato faltante = brecha visual en la serie.

[DATA-002]  error  — MUST NOT: celebración visual (animación de confetti, emojis de trofeo)
            por acción de captura. La app mide, no gamifica.

[DATA-003]  warn   — SHOULD NOT: valor "0" donde el dato genuinamente no existe.
            Usar "—" o null en vez de 0 para días sin registrar.

[NAV-001]   warn   — SHOULD: módulos sin datos no aparecen en NavigationBar hasta que
            el módulo haya recibido al menos un evento.

[NAV-002]   error  — MUST NOT: FAB múltiples en la misma pantalla.

[THEME-001] error  — MUST: ThemeData se define una sola vez en el composition root.
            never: ThemeData dentro de un widget o provider de módulo.
```

---

## Changelog

- **2026-06-11 — alpha.1:** `text-muted` aclarado `#8B949E` → `#9DA7B3`. El valor anterior pasaba AA numéricamente (4.9:1 sobre surface-raised) pero a 11sp en los labels y helpers de formularios se percibía lavado en el A71 (feedback de uso real). El nuevo da 6.2:1 sobre surface-raised y 7.7:1 sobre bg sin romper la jerarquía frente a `text`.
- **2026-06-11 — alpha:** Versión inicial. Paleta oscura + teal eléctrico (instrumento de precisión). DM Sans + DM Mono. Componentes hub, gym, days, sleep, affect. Reglas verificables con IDs. Diseñado para Samsung A71 (AMOLED, 393dp), local-first, dark-first.
