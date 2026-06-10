import 'domain_event.dart';

/// Registro de deserializadores: (eventType, schemaVersion) → fábrica.
///
/// Aquí vive el costo permanente de ES que discutimos: los eventos
/// persistidos son un contrato para siempre. Este registro es el único
/// punto del sistema que conoce TODAS las versiones históricas de cada
/// evento.
abstract class EventTypeRegistry {
  void register(
    String eventType,
    int schemaVersion,
    DomainEvent Function(Map<String, dynamic> json) factory,
  );

  /// Lanza [UnknownEventTypeException] si nadie registró ese tipo/versión.
  /// Política estricta a propósito: un evento que no sabemos leer es un bug
  /// de versionado, no algo que ignorar en silencio.
  DomainEvent deserialize(
    String eventType,
    int schemaVersion,
    Map<String, dynamic> json,
  );
}

/// Transforma el JSON de una versión vieja de un evento a la siguiente.
/// Los upcasters se encadenan: v1→v2→v3. El dominio solo ve la última
/// versión; las viejas existen únicamente en disco y en esta capa.
///
/// Estrategia elegida para empezar: weak schema (campos nuevos opcionales
/// con default) y upcasters solo cuando el default no alcance. Evita
/// proliferación de clases WorkoutLoggedV2, V3...
abstract class Upcaster {
  String get eventType;

  /// Versión que consume (transforma de [fromVersion] a [fromVersion] + 1).
  int get fromVersion;

  Map<String, dynamic> upcast(Map<String, dynamic> json);
}

/// Implementación por defecto del registro, con encadenado de upcasters.
///
/// Uso normal (weak schema): registrar SOLO la última versión de cada tipo;
/// la fábrica tolera campos faltantes con defaults. Cuando el default no
/// alcanza, se agrega un [Upcaster] por cada salto de versión vieja y la
/// fábrica sigue siendo una sola.
///
/// [deserialize] busca fábrica exacta para (tipo, versión); si no hay,
/// aplica upcasters v→v+1 hasta alcanzar una versión registrada. Si la
/// cadena se corta, [UnknownEventTypeException] — política estricta.
class DefaultEventTypeRegistry implements EventTypeRegistry {
  final Map<(String, int), DomainEvent Function(Map<String, dynamic>)>
      _factories = {};
  final Map<(String, int), Upcaster> _upcasters = {};

  @override
  void register(
    String eventType,
    int schemaVersion,
    DomainEvent Function(Map<String, dynamic> json) factory,
  ) {
    _factories[(eventType, schemaVersion)] = factory;
  }

  void registerUpcaster(Upcaster upcaster) {
    _upcasters[(upcaster.eventType, upcaster.fromVersion)] = upcaster;
  }

  @override
  DomainEvent deserialize(
    String eventType,
    int schemaVersion,
    Map<String, dynamic> json,
  ) {
    var version = schemaVersion;
    var payload = json;
    while (!_factories.containsKey((eventType, version))) {
      final upcaster = _upcasters[(eventType, version)];
      if (upcaster == null) {
        throw UnknownEventTypeException(eventType, version);
      }
      payload = upcaster.upcast(payload);
      version++;
    }
    return _factories[(eventType, version)]!(payload);
  }
}

class UnknownEventTypeException implements Exception {
  final String eventType;
  final int schemaVersion;
  UnknownEventTypeException(this.eventType, this.schemaVersion);

  @override
  String toString() =>
      'Tipo de evento no registrado: $eventType v$schemaVersion';
}
