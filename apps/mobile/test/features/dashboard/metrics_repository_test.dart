import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_operation.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_outbox.dart';
import 'package:tu_vacuna_pai/features/dashboard/data/metrics_repository_impl.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxRepository outbox;
  late MetricsRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = SyncOutboxRepository(db);
    repository = MetricsRepositoryImpl(
      api: ApiClient(baseUrl: 'http://localhost'),
      database: db,
      outbox: outbox,
    );
  });

  tearDown(() => db.close());

  test('sin cache cuenta el working set local de la institucion', () async {
    await db.upsertAttentionLocal(
      AttentionsLocalCompanion.insert(
        id: 'att-1',
        institutionId: 'inst-1',
        patientId: 'pat-1',
        status: 'DRAFT',
        version: 0,
        syncState: 'PENDING_SYNC',
        updatedAt: 0,
      ),
    );
    await db.upsertAppliedDoseLocal(
      AppliedDosesLocalCompanion.insert(
        id: 'dose-1',
        attentionId: 'att-1',
        status: 'REGISTERED',
        appliedAt: 0,
        vaccineNameSnapshot: 'Influenza',
        syncState: 'PENDING_SYNC',
        updatedAt: 0,
      ),
    );

    final summary = await repository.localSummary('inst-1');

    expect(summary.patientsAttended, 1);
    expect(summary.dosesApplied, 1);
  });

  test('con cache suma los comprobantes pendientes del outbox', () async {
    await db.setSyncMetadata(
      'metrics_summary',
      '{"patientsAttended":5,"dosesApplied":8}',
    );
    await outbox.enqueue(
      const SyncOperation(
        operationId: 'op-att',
        commandType: SyncCommandType.createAttention,
        aggregateId: 'att-1',
        payload: {},
      ),
    );
    await outbox.enqueue(
      const SyncOperation(
        operationId: 'op-dose',
        commandType: SyncCommandType.registerAppliedDose,
        aggregateId: 'dose-1',
        payload: {},
      ),
    );

    final summary = await repository.localSummary('inst-1');

    expect(summary.patientsAttended, 6);
    expect(summary.dosesApplied, 9);
  });
}
