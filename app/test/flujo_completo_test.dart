import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/gym.dart';
import 'package:hub/hub.dart';
import 'package:lifeos_app/main.dart';
import 'package:lifeos_app/src/providers.dart';

/// El walking skeleton de punta a punta por la UI real: empezar entreno,
/// registrar series, terminarlo, verlo en el historial y ver la estadística
/// del hub en Inicio (integration event mediante). Misma composición que
/// main(), con la database en memoria.
void main() {
  setUpAll(configureSqliteNativeLibrary);

  Future<TestDatabase> pumpApp(WidgetTester tester) async {
    final db = TestDatabase();
    await createEventStoreSchema(db);
    await createIntegrationEventSchema(db);
    await createGymReadModelSchema(db);
    await createHubReadModelSchema(db);
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWith((ref) => db)],
      child: const LifeosApp(),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> irA(WidgetTester tester, String tab) async {
    await tester.tap(find.widgetWithText(NavigationDestination, tab));
    await tester.pumpAndSettle();
  }

  /// Selección por el picker real (ADR-0011): elige del catálogo o crea
  /// al vuelo si el ejercicio todavía no existe.
  Future<void> elegirEjercicio(
      WidgetTester tester, Key campo, String nombre,
      {String grupo = 'pierna'}) async {
    await tester.tap(find.byKey(campo));
    await tester.pumpAndSettle();
    final existente = find.widgetWithText(ListTile, nombre);
    if (existente.evaluate().isNotEmpty) {
      await tester.tap(existente.first);
    } else {
      await tester.tap(find.byKey(const Key('nuevo-ejercicio')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('nombre-ejercicio')), nombre);
      await tester.tap(find.byKey(const Key('grupo-muscular')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(grupo).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-ejercicio')));
    }
    await tester.pumpAndSettle();
  }

  Future<void> registrarSerie(
    WidgetTester tester, {
    required String ejercicio,
    required String peso,
    required String reps,
  }) async {
    await elegirEjercicio(tester, const Key('ejercicio'), ejercicio);
    await tester.enterText(find.byKey(const Key('peso')), peso);
    await tester.enterText(find.byKey(const Key('reps')), reps);
    await tester.tap(find.byKey(const Key('registrar')));
    await tester.pumpAndSettle();
  }

  testWidgets('empezar → loggear → terminar → historial → hub en Inicio',
      (tester) async {
    await pumpApp(tester);

    // Arranca en Inicio: la estadística del hub en cero.
    expect(find.text('Entrenos esta semana'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await irA(tester, 'Entrenar');
    expect(find.byKey(const Key('empezar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('registrar')), findsOneWidget);

    // Día de pierna (docs/gym_inventario.md): 80×10 + 80×8 = 1440 kg.
    await registrarSerie(tester,
        ejercicio: 'sentadilla', peso: '80', reps: '10');
    await registrarSerie(tester, ejercicio: 'sentadilla', peso: '80', reps: '8');
    expect(find.text('1440 kg'), findsOneWidget); // contador en vivo

    await tester.tap(find.byKey(const Key('terminar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empezar')), findsOneWidget);

    // Historial: el entreno completado y el volumen semanal derivado.
    await irA(tester, 'Historial');
    expect(find.text('2 series · 1440 kg'), findsOneWidget);
    expect(find.textContaining('Semana del'), findsOneWidget);
    expect(find.text('en curso'), findsNothing);

    // Inicio: el integration event cruzó la frontera hacia el hub.
    await irA(tester, 'Inicio');
    expect(find.text('1'), findsOneWidget);

    // La estadística es un atajo al módulo (visor/redireccionador).
    await tester.tap(find.byKey(const Key('stat-gym')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Semana del'), findsOneWidget);
  });

  Future<void> entrenoCompleto(WidgetTester tester) async {
    await irA(tester, 'Entrenar');
    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();
    await registrarSerie(tester,
        ejercicio: 'sentadilla', peso: '80', reps: '10');
    await registrarSerie(tester, ejercicio: 'sentadilla', peso: '80', reps: '8');
    await tester.tap(find.byKey(const Key('terminar')));
    await tester.pumpAndSettle();
  }

  testWidgets('descartar el entreno en curso lo borra sin dejar rastro '
      '(ADR-0010)', (tester) async {
    await pumpApp(tester);
    await irA(tester, 'Entrenar');
    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();

    // El caso bf0d7bfd: un tap por error y antes no había salida.
    await tester.tap(find.byKey(const Key('descartar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-descarte')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('empezar')), findsOneWidget,
        reason: 'ya no hay workout en curso');
    await irA(tester, 'Historial');
    expect(find.text('Todavía no hay entrenos.'), findsOneWidget);
  });

  testWidgets('descartar un completado desde Historial descuenta también '
      'la estadística del hub (ADR-0010)', (tester) async {
    await pumpApp(tester);
    await entrenoCompleto(tester);

    await irA(tester, 'Inicio');
    expect(find.text('1'), findsOneWidget);

    await irA(tester, 'Historial');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-descarte')));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay entrenos.'), findsOneWidget);
    await irA(tester, 'Inicio');
    expect(find.text('0'), findsOneWidget,
        reason: 'el integration event compensatorio cruzó la frontera');
  });

  testWidgets('agregar una serie olvidada a un completado suma series y '
      'volumen (ADR-0010)', (tester) async {
    await pumpApp(tester);
    await entrenoCompleto(tester); // 2 series · 1440 kg

    await irA(tester, 'Historial');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar serie olvidada…'));
    await tester.pumpAndSettle();

    // El caso real: la serie de calves que quedó sin registrar.
    await elegirEjercicio(
        tester, const Key('tardia-ejercicio'), 'calf raises');
    await tester.enterText(find.byKey(const Key('tardia-peso')), '40');
    await tester.enterText(find.byKey(const Key('tardia-reps')), '12');
    await tester.tap(find.byKey(const Key('confirmar-tardia')));
    await tester.pumpAndSettle();

    expect(find.text('3 series · 1920 kg'), findsOneWidget);
  });

  testWidgets('las invariantes del dominio llegan como SnackBar',
      (tester) async {
    await pumpApp(tester);
    await irA(tester, 'Entrenar');
    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();

    // Terminar sin series: el agregado lo rechaza (ADR-0007).
    await tester.tap(find.byKey(const Key('terminar')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('registrar')), findsOneWidget,
        reason: 'el workout sigue en curso: el evento nunca se persistió');

    // reps = 0 viola la invariante de la serie: el contador sigue en 0.
    await registrarSerie(tester, ejercicio: 'press banca', peso: '60', reps: '0');
    expect(find.text('0'), findsOneWidget,
        reason: 'el contador de series no se movió');
    expect(find.byType(SnackBar), findsWidgets);
  });

  testWidgets('input no numérico se rechaza en la UI, sin tocar el dominio',
      (tester) async {
    final db = await pumpApp(tester);
    await irA(tester, 'Entrenar');
    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();

    await registrarSerie(tester,
        ejercicio: 'sentadilla', peso: 'ochenta', reps: '10');
    expect(find.text('Peso y reps deben ser números.'), findsOneWidget);

    final series = await db
        .customSelect(
            "SELECT * FROM events WHERE event_type = 'gym.set_logged'")
        .get();
    expect(series, isEmpty,
        reason: 'ningún set_logged llegó al store (el alta del ejercicio '
            'al vuelo sí es un evento legítimo)');
  });

  testWidgets('catálogo: crear desde Ejercicios, renombrar, y la unicidad '
      'llega como SnackBar (ADR-0011)', (tester) async {
    await pumpApp(tester);
    await irA(tester, 'Ejercicios');
    expect(find.textContaining('El catálogo está vacío'), findsOneWidget);

    // Alta con nombre histórico: vincula las series viejas a texto libre.
    await tester.tap(find.byKey(const Key('nuevo-ejercicio-catalogo')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('nombre-ejercicio')), 'Calf raises');
    await tester.tap(find.byKey(const Key('grupo-muscular')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pierna').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('nombres-historicos')), 'Calves');
    await tester.tap(find.byKey(const Key('confirmar-ejercicio')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Calf raises'), findsOneWidget);
    expect(find.text('pierna'), findsOneWidget, reason: 'header del grupo');

    // La invariante de unicidad cruza desde el agregado como SnackBar
    // ("Calves" ya pertenece a Calf raises como nombre histórico).
    await tester.tap(find.byKey(const Key('nuevo-ejercicio-catalogo')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('nombre-ejercicio')), 'Calves');
    await tester.tap(find.byKey(const Key('grupo-muscular')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pierna').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-ejercicio')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Calves'), findsNothing);

    // Renombrar: el nombre visible cambia (el vínculo viejo persiste en
    // el read model, cubierto por los tests del módulo).
    await tester.tap(find.widgetWithText(ListTile, 'Calf raises'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('renombrar-nombre')), 'Standing calf raise');
    await tester.tap(find.byKey(const Key('confirmar-renombrar')));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(ListTile, 'Standing calf raise'), findsOneWidget);
  });

  testWidgets('el picker registra la serie con la identidad del catálogo '
      '(exerciseId en el evento)', (tester) async {
    final db = await pumpApp(tester);
    await irA(tester, 'Entrenar');
    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();

    await registrarSerie(tester,
        ejercicio: 'Leg press', peso: '180', reps: '10');

    final serie = await db
        .customSelect(
            "SELECT payload FROM events WHERE event_type = 'gym.set_logged'")
        .get();
    final payload = serie.single.read<String>('payload');
    expect(payload, contains('"exerciseId"'),
        reason: 'la serie quedó vinculada al catálogo, no solo al nombre');
    expect(payload, contains('"exercise":"Leg press"'),
        reason: 'y conserva el nombre denormalizado');
  });
}
