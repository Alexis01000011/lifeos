import 'package:core_drift/core_drift.dart';
import 'package:core_drift/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/gym.dart';
import 'package:lifeos_app/main.dart';
import 'package:lifeos_app/src/providers.dart';

/// El walking skeleton de punta a punta por la UI real: empezar entreno,
/// registrar series, terminarlo y verlo en el historial con su volumen.
/// Misma composición que main(), con la database en memoria.
void main() {
  setUpAll(configureSqliteNativeLibrary);

  Future<TestDatabase> pumpApp(WidgetTester tester) async {
    final db = TestDatabase();
    await createEventStoreSchema(db);
    await createGymReadModelSchema(db);
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWith((ref) => db)],
      child: const LifeosApp(),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> registrarSerie(
    WidgetTester tester, {
    required String ejercicio,
    required String peso,
    required String reps,
  }) async {
    await tester.enterText(find.byKey(const Key('ejercicio')), ejercicio);
    await tester.enterText(find.byKey(const Key('peso')), peso);
    await tester.enterText(find.byKey(const Key('reps')), reps);
    await tester.tap(find.byKey(const Key('registrar')));
    await tester.pumpAndSettle();
  }

  testWidgets('empezar → loggear → terminar → historial', (tester) async {
    await pumpApp(tester);

    // Sin entreno en curso: solo está el botón de empezar.
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
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('2 series · 1440 kg'), findsOneWidget);
    expect(find.textContaining('Semana del'), findsOneWidget);
    expect(find.text('en curso'), findsNothing);
  });

  testWidgets('las invariantes del dominio llegan como SnackBar',
      (tester) async {
    await pumpApp(tester);
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
    await tester.tap(find.byKey(const Key('empezar')));
    await tester.pumpAndSettle();

    await registrarSerie(tester,
        ejercicio: 'sentadilla', peso: 'ochenta', reps: '10');
    expect(find.text('Peso y reps deben ser números.'), findsOneWidget);

    final eventos = await db.customSelect('SELECT * FROM events').get();
    expect(eventos, hasLength(1),
        reason: 'solo workout_started; ningún set_logged llegó al store');
  });
}
