import 'dart:io';

import 'package:core_drift/core_drift.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gym/gym.dart';
import 'package:hub/hub.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// La database compuesta (ADR-0006): un único archivo SQLite donde
/// conviven el event store y las tablas de read model de cada módulo,
/// para que el append y las proyecciones síncronas compartan transacción.
///
/// Escrita a mano, sin codegen: todas las tablas se crean con SQL crudo
/// (ADR-0006/ADR-0008), así que Drift no declara ninguna.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// Abre (o crea) la base en el directorio de documentos de la app y
/// asegura los schemas. Los create son idempotentes: cada módulo nuevo
/// agrega su llamada aquí y nada más.
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'lifeos.sqlite'));
  final db = AppDatabase(NativeDatabase.createInBackground(file));
  await createEventStoreSchema(db);
  await createIntegrationEventSchema(db);
  await createGymReadModelSchema(db);
  await createHubReadModelSchema(db);
  return db;
}
