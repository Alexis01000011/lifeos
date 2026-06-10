import 'package:core/core.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

void main() {
  Workout iniciado() => Workout('w1')..start();

  Workout conSerie() => iniciado()
    ..logSet(exercise: 'press banca', weightKg: 60, reps: 8);

  group('start', () {
    test('emite WorkoutStarted', () {
      final workout = iniciado();
      expect(workout.uncommittedEvents.single, isA<WorkoutStarted>());
      expect(workout.version, 1);
    });

    test('no puede iniciarse dos veces', () {
      expect(() => iniciado().start(), throwsA(isA<DomainException>()));
    });
  });

  group('logSet', () {
    test('emite SetLogged con el ejercicio normalizado', () {
      final workout = iniciado()
        ..logSet(
            exercise: '  sentadilla ',
            weightKg: 80,
            reps: 5,
            restBeforeSeconds: 120);

      final set = workout.uncommittedEvents.last as SetLogged;
      expect(set.exercise, 'sentadilla');
      expect(set.weightKg, 80);
      expect(set.reps, 5);
      expect(set.restBeforeSeconds, 120);
      expect(workout.setCount, 1);
    });

    test('peso 0 es válido (ejercicios a peso corporal)', () {
      expect(
          () => iniciado().logSet(exercise: 'dominadas', weightKg: 0, reps: 10),
          returnsNormally);
    });

    test('rechaza workout no iniciado, completado, ejercicio vacío, '
        'reps < 1, peso o descanso negativos', () {
      final completado = conSerie()..complete();
      final casos = <void Function()>[
        () => Workout('w2').logSet(exercise: 'x', weightKg: 1, reps: 1),
        () => completado.logSet(exercise: 'x', weightKg: 1, reps: 1),
        () => iniciado().logSet(exercise: '   ', weightKg: 1, reps: 1),
        () => iniciado().logSet(exercise: 'x', weightKg: 1, reps: 0),
        () => iniciado().logSet(exercise: 'x', weightKg: -1, reps: 1),
        () => iniciado().logSet(
            exercise: 'x', weightKg: 1, reps: 1, restBeforeSeconds: -5),
      ];
      for (final caso in casos) {
        expect(caso, throwsA(isA<DomainException>()));
      }
    });
  });

  group('complete', () {
    test('emite WorkoutCompleted', () {
      final workout = conSerie()..complete();
      expect(workout.isCompleted, isTrue);
      expect(workout.uncommittedEvents.last, isA<WorkoutCompleted>());
    });

    test('rechaza workout sin series, no iniciado o ya completado', () {
      expect(() => iniciado().complete(), throwsA(isA<DomainException>()));
      expect(() => Workout('w2').complete(), throwsA(isA<DomainException>()));
      expect(() => (conSerie()..complete()).complete(),
          throwsA(isA<DomainException>()));
    });
  });

  test('rehydrate reconstruye el estado y permite seguir operando', () {
    final original = conSerie();
    final history = [
      for (final (i, event) in original.uncommittedEvents.indexed)
        EventEnvelope(
          eventId: 'evt-${i + 1}',
          streamId: StreamId(Workout.aggregateTypeName, 'w1'),
          streamVersion: i + 1,
          globalSequence: i + 1,
          occurredAt: DateTime.utc(2026, 6, 10),
          event: event,
        ),
    ];

    final rehidratado = Workout('w1')..rehydrate(history);

    expect(rehidratado.version, 2);
    expect(rehidratado.setCount, 1);
    expect(rehidratado.isCompleted, isFalse);
    expect(() => rehidratado.complete(), returnsNormally);
    expect(rehidratado.uncommittedEvents.single, isA<WorkoutCompleted>());
  });
}
