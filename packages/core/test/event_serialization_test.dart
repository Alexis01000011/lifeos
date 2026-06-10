import 'package:core/core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Upcaster de juguete: v1 guardaba 'data'; v2 lo renombra a 'payload'.
class RenameDataUpcaster implements Upcaster {
  @override
  final String eventType;
  @override
  final int fromVersion;

  RenameDataUpcaster(this.eventType, this.fromVersion);

  @override
  Map<String, dynamic> upcast(Map<String, dynamic> json) => {
        for (final e in json.entries)
          if (e.key != 'data') e.key: e.value,
        'payload': json['data'],
      };
}

void main() {
  late DefaultEventTypeRegistry<DomainEvent> registry;

  setUp(() => registry = DefaultEventTypeRegistry<DomainEvent>());

  test('roundtrip: deserializa con la fábrica exacta de (tipo, versión)', () {
    registry.register(
        'test.evt', 1, (json) => TestEvent('test.evt', json['data'] as String));

    final event =
        registry.deserialize('test.evt', 1, {'data': 'hola'}) as TestEvent;

    expect(event.data, 'hola');
  });

  test('tipo no registrado lanza UnknownEventTypeException (política estricta)',
      () {
    expect(
      () => registry.deserialize('fantasma.evt', 1, {}),
      throwsA(isA<UnknownEventTypeException>()),
    );
  });

  test('encadena upcasters hasta la versión con fábrica registrada', () {
    // Solo está registrada la v3; el disco trae una v1.
    registry.register('test.evt', 3,
        (json) => TestEvent('test.evt', json['payload'] as String));
    registry.registerUpcaster(RenameDataUpcaster('test.evt', 1)); // v1→v2
    registry.registerUpcaster(_AddSuffixUpcaster('test.evt', 2)); // v2→v3

    final event =
        registry.deserialize('test.evt', 1, {'data': 'hola'}) as TestEvent;

    expect(event.data, 'hola!');
  });

  test('cadena de upcasters incompleta lanza UnknownEventTypeException', () {
    registry.register('test.evt', 3,
        (json) => TestEvent('test.evt', json['payload'] as String));
    // Falta el upcaster v2→v3.
    registry.registerUpcaster(RenameDataUpcaster('test.evt', 1));

    expect(
      () => registry.deserialize('test.evt', 1, {'data': 'hola'}),
      throwsA(isA<UnknownEventTypeException>()),
    );
  });

  test('la versión exacta gana: no upcastea si hay fábrica para la vieja', () {
    registry.register(
        'test.evt', 1, (json) => TestEvent('test.evt', json['data'] as String));
    registry.register('test.evt', 2,
        (json) => TestEvent('test.evt', json['payload'] as String));
    registry.registerUpcaster(RenameDataUpcaster('test.evt', 1));

    final event =
        registry.deserialize('test.evt', 1, {'data': 'directo'}) as TestEvent;

    expect(event.data, 'directo');
  });
}

class _AddSuffixUpcaster implements Upcaster {
  @override
  final String eventType;
  @override
  final int fromVersion;

  _AddSuffixUpcaster(this.eventType, this.fromVersion);

  @override
  Map<String, dynamic> upcast(Map<String, dynamic> json) =>
      {...json, 'payload': '${json['payload']}!'};
}
