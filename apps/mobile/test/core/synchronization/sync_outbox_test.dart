import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_operation.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_outbox.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxRepository outbox;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = SyncOutboxRepository(db);
  });

  tearDown(() => db.close());

  SyncOperation operation(String id, {List<String> dependencies = const []}) =>
      SyncOperation(
        operationId: id,
        commandType: SyncCommandType.createPatient,
        aggregateId: 'agg-$id',
        payload: const {'documentType': 'CC'},
        dependencies: dependencies,
      );

  test('encola operaciones y las lee en orden con sus dependencias', () async {
    await outbox.enqueue(operation('op1'));
    await outbox.enqueue(operation('op2', dependencies: ['op1']));

    final pending = await outbox.pendingOperations();

    expect(pending.map((entry) => entry.operation.operationId), ['op1', 'op2']);
    expect(pending[0].operation.payload, {'documentType': 'CC'});
    expect(pending[1].operation.dependencies, ['op1']);
    expect(await outbox.pendingCount(), 2);
  });

  test('commitLocalWrite guarda el agregado y el outbox juntos', () async {
    await outbox.commitLocalWrite(
      writeLocal: () => db.upsertPatientLocal(
        PatientsLocalCompanion.insert(
          id: 'p1',
          institutionId: 'i1',
          documentType: 'CC',
          documentNumber: '123',
          firstName: 'Ana',
          lastName: 'Perez',
          syncState: SyncAggregateState.pendingSync.value,
          version: 0,
          updatedAt: 0,
        ),
      ),
      operation: operation('op1'),
    );

    final patient = await db.patientLocalById('p1');
    expect(patient, isNotNull);
    expect(patient!.documentNumber, '123');
    expect(await outbox.pendingCount(), 1);
  });

  test('resetProcessingToPending devuelve lo atascado a la cola', () async {
    await outbox.enqueue(operation('op1'));
    await outbox.markProcessing('op1');

    await outbox.resetProcessingToPending();

    final pending = await outbox.pendingOperations();
    expect(pending.single.status, SyncOutboxStatus.pending);
  });

  test(
    'markCompleted y markQuarantined cambian el estado persistido',
    () async {
      await outbox.enqueue(operation('ok'));
      await outbox.enqueue(operation('bad'));
      await outbox.markCompleted('ok');
      await outbox.markQuarantined('bad', error: 'USER_NOT_ACTIVE');

      expect(
        (await outbox.byOperationId('ok'))!.status,
        SyncOutboxStatus.completed,
      );
      final bad = await outbox.byOperationId('bad');
      expect(bad!.status, SyncOutboxStatus.quarantined);
      expect(await outbox.pendingCount(), 0);
    },
  );

  test('pendingEntries expone resumen, estado y fecha de encolado', () async {
    await outbox.enqueue(
      SyncOperation(
        operationId: 'op1',
        commandType: SyncCommandType.registerAppliedDose,
        aggregateId: 'dose-1',
        payload: const {'vaccineId': 'vac-1'},
        summary: 'Vacuna aplicada - Influenza',
      ),
    );

    final entries = await outbox.pendingEntries();

    expect(entries, hasLength(1));
    expect(entries.single.operation.summary, 'Vacuna aplicada - Influenza');
    expect(entries.single.status, SyncOutboxStatus.pending);
    expect(entries.single.createdAt, isNotNull);
    // El resumen es metadata local: no viaja en el push.
    expect(entries.single.operation.toJson().containsKey('summary'), isFalse);
  });
}
