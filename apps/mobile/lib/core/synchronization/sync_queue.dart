import 'sync_operation.dart';

/// Ordena las operaciones del outbox respetando sus dependencias (orden
/// topologico). El outbox ya se inserta en orden de creacion, pero este
/// ordenamiento protege ante encolados fuera de orden.
class SyncQueue {
  const SyncQueue._();

  static List<OutboxEntry> order(List<OutboxEntry> entries) {
    final byId = {
      for (final entry in entries) entry.operation.operationId: entry,
    };
    final ordered = <OutboxEntry>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(OutboxEntry entry) {
      final id = entry.operation.operationId;
      if (visited.contains(id)) return;
      if (!visiting.add(id)) return;
      for (final dependency in entry.operation.dependencies) {
        final parent = byId[dependency];
        if (parent != null) visit(parent);
      }
      visiting.remove(id);
      visited.add(id);
      ordered.add(entry);
    }

    for (final entry in entries) {
      visit(entry);
    }
    return ordered;
  }
}
