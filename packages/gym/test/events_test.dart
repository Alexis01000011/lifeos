import 'package:core/core.dart';
import 'package:gym/gym.dart';
import 'package:test/test.dart';

void main() {
  late DefaultEventTypeRegistry<DomainEvent> registry;

  setUp(() {
    registry = DefaultEventTypeRegistry<DomainEvent>();
    registerGymEvents(registry);
  });

  DomainEvent roundtrip(DomainEvent event) =>
      registry.deserialize(event.eventType, event.schemaVersion, event.toJson());

  test('SetLogged sobrevive el roundtrip completo', () {
    final leido = roundtrip(SetLogged(
      exercise: 'peso muerto',
      weightKg: 102.5,
      reps: 3,
      restBeforeSeconds: 180,
    )) as SetLogged;

    expect(leido.exercise, 'peso muerto');
    expect(leido.weightKg, 102.5);
    expect(leido.reps, 3);
    expect(leido.restBeforeSeconds, 180);
  });

  test('SetLogged sin descanso: el campo ausente deserializa a null '
      '(weak schema)', () {
    final leido = roundtrip(
            SetLogged(exercise: 'dominadas', weightKg: 0, reps: 10))
        as SetLogged;
    expect(leido.restBeforeSeconds, isNull);
  });

  test('los eventos de ciclo de vida sobreviven el roundtrip', () {
    expect(roundtrip(WorkoutStarted()), isA<WorkoutStarted>());
    expect(roundtrip(WorkoutCompleted()), isA<WorkoutCompleted>());
  });

  test('los eventType son estables (contrato de persistencia)', () {
    expect(WorkoutStarted.type, 'gym.workout_started');
    expect(SetLogged.type, 'gym.set_logged');
    expect(WorkoutCompleted.type, 'gym.workout_completed');
  });
}
