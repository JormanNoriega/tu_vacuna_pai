import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_operation.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_queue.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status.dart';

OutboxEntry _entry(String id, {List<String> dependencies = const []}) =>
    OutboxEntry(
      operation: SyncOperation(
        operationId: id,
        commandType: SyncCommandType.registerAppliedDose,
        aggregateId: 'agg-$id',
        payload: const {},
        dependencies: dependencies,
      ),
      status: SyncOutboxStatus.pending,
      retryCount: 0,
    );

void main() {
  group('SyncQueue', () {
    test('ordena respetando dependencias aunque lleguen desordenadas', () {
      final ordered = SyncQueue.order([
        _entry('dose', dependencies: ['attention']),
        _entry('patient'),
        _entry('attention', dependencies: ['patient']),
      ]);

      expect(
        ordered.map((entry) => entry.operation.operationId),
        ['patient', 'attention', 'dose'],
      );
    });

    test('ignora dependencias ausentes sin bloquear el batch', () {
      final ordered = SyncQueue.order([
        _entry('a', dependencies: ['desconocida']),
      ]);

      expect(ordered.map((entry) => entry.operation.operationId), ['a']);
    });
  });
}
