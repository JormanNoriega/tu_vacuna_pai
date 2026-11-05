import 'package:drift/drift.dart' show Value;
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

  test(
    'filtra metricas por vaccinatorId para mostrar conteo personal',
    () async {
      // Atencion de vacunadora A
      await db.upsertAttentionLocal(
        AttentionsLocalCompanion.insert(
          id: 'att-1',
          institutionId: 'inst-1',
          patientId: 'pat-1',
          vaccinatorId: const Value('vac-a'),
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

      // Atencion de vacunadora B en el mismo hospital
      await db.upsertAttentionLocal(
        AttentionsLocalCompanion.insert(
          id: 'att-2',
          institutionId: 'inst-1',
          patientId: 'pat-2',
          vaccinatorId: const Value('vac-b'),
          status: 'DRAFT',
          version: 0,
          syncState: 'PENDING_SYNC',
          updatedAt: 0,
        ),
      );
      await db.upsertAppliedDoseLocal(
        AppliedDosesLocalCompanion.insert(
          id: 'dose-2',
          attentionId: 'att-2',
          status: 'REGISTERED',
          appliedAt: 0,
          vaccineNameSnapshot: 'Polio',
          syncState: 'PENDING_SYNC',
          updatedAt: 0,
        ),
      );

      // Conteo institucional (admin: sin vaccinatorId)
      final adminSummary = await repository.localSummary('inst-1');
      expect(adminSummary.patientsAttended, 2);
      expect(adminSummary.dosesApplied, 2);

      // Conteo personal vacunadora A
      final vacASummary = await repository.localSummary(
        'inst-1',
        vaccinatorId: 'vac-a',
      );
      expect(vacASummary.patientsAttended, 1);
      expect(vacASummary.dosesApplied, 1);

      // Conteo personal vacunadora B
      final vacBSummary = await repository.localSummary(
        'inst-1',
        vaccinatorId: 'vac-b',
      );
      expect(vacBSummary.patientsAttended, 1);
      expect(vacBSummary.dosesApplied, 1);
    },
  );

  test(
    'obtiene ultimos registros locales con datos de paciente y vacuna',
    () async {
      await db.upsertPatientLocal(
        PatientsLocalCompanion.insert(
          id: 'pat-1',
          institutionId: 'inst-1',
          documentType: 'CC',
          documentNumber: '12345678',
          firstName: 'Julio',
          lastName: 'Rios',
          syncState: 'SYNCED',
          version: 1,
          updatedAt: 0,
        ),
      );
      await db.upsertAttentionLocal(
        AttentionsLocalCompanion.insert(
          id: 'att-1',
          institutionId: 'inst-1',
          patientId: 'pat-1',
          status: 'COMPLETED',
          attentionDate: const Value(1730780000),
          version: 1,
          syncState: 'SYNCED',
          updatedAt: 0,
        ),
      );
      await db.upsertAppliedDoseLocal(
        AppliedDosesLocalCompanion.insert(
          id: 'dose-1',
          attentionId: 'att-1',
          status: 'REGISTERED',
          appliedAt: 1730780000,
          vaccineNameSnapshot: 'COVID-19',
          syncState: 'SYNCED',
          updatedAt: 0,
        ),
      );

      final recents = await repository.localRecentRecords('inst-1');
      expect(recents.length, 1);
      expect(recents.first.patientId, 'pat-1');
      expect(recents.first.patientName, 'Julio Rios');
      expect(recents.first.vaccineName, 'COVID-19');
      expect(recents.first.timeAgo, isNotEmpty);
    },
  );
}
