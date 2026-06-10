import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

/// GeneratedDatabase mínima escrita a mano (sin codegen) sobre SQLite en
/// memoria. Sin tablas Drift declaradas: en este proyecto las tablas de
/// infraestructura y de read models se crean con SQL crudo
/// (ADR-0006/ADR-0008).
class TestDatabase extends GeneratedDatabase {
  TestDatabase() : super(NativeDatabase.memory());

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// En Windows el paquete sqlite3 busca sqlite3.dll; si no está en el PATH,
/// caemos a winsqlite3.dll (incluida en Windows 10+).
void configureSqliteNativeLibrary() {
  if (!Platform.isWindows) return;
  open.overrideFor(OperatingSystem.windows, () {
    for (final lib in ['sqlite3.dll', 'winsqlite3.dll']) {
      try {
        return DynamicLibrary.open(lib);
      } catch (_) {}
    }
    throw StateError('No se encontró sqlite3.dll ni winsqlite3.dll');
  });
}
