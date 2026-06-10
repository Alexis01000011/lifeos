import 'package:core/core.dart';
import 'package:drift/drift.dart';

/// Checkpoints de proyección sobre la misma database compuesta.
/// Un projector que nunca guardó checkpoint está en 0 (no ha visto nada).
class DriftProjectionCheckpointStore implements ProjectionCheckpointStore {
  final GeneratedDatabase _db;

  DriftProjectionCheckpointStore(this._db);

  @override
  Future<int> getCheckpoint(String projectorName) async {
    final row = await _db.customSelect(
      'SELECT global_sequence FROM projection_checkpoints '
      'WHERE projector_name = ?',
      variables: [Variable<String>(projectorName)],
    ).getSingleOrNull();
    return row?.read<int>('global_sequence') ?? 0;
  }

  @override
  Future<void> saveCheckpoint(String projectorName, int globalSequence) {
    return _db.customStatement(
      'INSERT INTO projection_checkpoints (projector_name, global_sequence) '
      'VALUES (?, ?) '
      'ON CONFLICT (projector_name) '
      'DO UPDATE SET global_sequence = excluded.global_sequence',
      [projectorName, globalSequence],
    );
  }
}
