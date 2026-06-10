# lifeos_app — app shell

La única capa que puede depender de todos (VISION.md): compone la database,
el registry de eventos, el engine de proyecciones y las pantallas de los
módulos. Cero lógica de negocio.

## Composición (Fase 3)

- `src/database.dart` — `AppDatabase`: la database compuesta de ADR-0006
  (event store + read models de módulos en un archivo SQLite, sin codegen).
  `openAppDatabase()` la abre y asegura los schemas (idempotentes): un
  módulo nuevo agrega ahí su `create<Modulo>ReadModelSchema`.
- `src/providers.dart` — composition root con Riverpod (ADR-0002, estado Y
  DI): `databaseProvider` se overridea en `main()` (tests: database en
  memoria); store/handlers/read models se derivan de él. Los read models
  llegan a la UI como `StreamProvider` sobre `watchQuery` (ADR-0008).
- `src/screens/` — UI delgada: lee proyecciones, despacha comandos; las
  invariantes del dominio llegan como `DomainException` y se muestran tal
  cual (SnackBar). `home_screen.dart` (Inicio) es el embrión de la pantalla
  principal de VISION: estadísticas del hub, clickeables hacia el módulo.
- Fase 4: `integrationEventLogProvider` compone el log de integración
  (ADR-0009) con los projectors del hub; la policy de gym se registra en el
  engine principal junto a los projectors del módulo.

## Tests

`flutter test` corre el walking skeleton entero por la UI real (empezar →
loggear → terminar → historial) contra SQLite en memoria, con la misma
composición que producción salvo el override de la database.

`test/acid_real_device_test.dart` corre la prueba ácida contra bases REALES
extraídas del A71 (instrucciones de extracción en el propio archivo; las
bases van en `tmp/`, gitignoreado por ser datos personales). Si `tmp/` está
vacío el test se salta — es una herramienta de auditoría, no parte del CI.

## Correr

- PC: `flutter run -d windows`
- A71: `flutter run` con el teléfono conectado (modo desarrollador + USB
  debugging), o `flutter build apk --release` e instalar el APK.
