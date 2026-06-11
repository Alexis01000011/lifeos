import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/database.dart';
import 'src/providers.dart';
import 'src/screens/exercises_screen.dart';
import 'src/screens/history_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/log_workout_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicialización async de la app: abrir la database compuesta, asegurar
  // schemas y poner las proyecciones al día (catch-up, ADR-0010 — así un
  // projector nuevo de esta versión se backfillea con los eventos viejos).
  // Todo lo demás se deriva de providers síncronos.
  final db = await openAppDatabase();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWith((ref) => db)],
  );
  await catchUpProjections(container);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const LifeosApp(),
  ));
}

class LifeosApp extends StatelessWidget {
  const LifeosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lifeos',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme:
          ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(switch (_index) {
        0 => 'lifeos',
        1 => 'Entrenar',
        2 => 'Historial',
        _ => 'Ejercicios',
      })),
      body: switch (_index) {
        0 => HomeScreen(onOpenGym: () => setState(() => _index = 2)),
        1 => const LogWorkoutScreen(),
        2 => const HistoryScreen(),
        _ => const ExercisesScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Entrenar'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(
              icon: Icon(Icons.list_alt), label: 'Ejercicios'),
        ],
      ),
    );
  }
}
