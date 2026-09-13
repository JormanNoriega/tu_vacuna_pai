import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';
import 'package:tu_vacuna_pai/core/synchronization/clinical_offline_repository.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_outbox.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/new_patient.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxRepository outbox;
  late ClinicalOfflineRepository clinical;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = SyncOutboxRepository(db);
    clinical = ClinicalOfflineRepository(database: db, outboxRepository: outbox);
    await db.upsertCurrentUser(
      id: 'user-1',
      email: 'vac@test.co',
      fullName: 'Vacunador',
      institutionId: 'inst-1',
      roles: const ['VACCINATOR'],
      permissions: const ['ATTENTION_CREATE', 'PATIENT_WRITE'],
      offlineWindowHours: 24,
      lastOnlineValidation: 0,
    );
  });

  tearDown(() => db.close());

  const input = NewPatientInput(
    documentType: 'CC',
    documentNumber: '10203040',
    firstName: 'Maria',
    lastName: 'Gomez',
    birthDate: '1990-05-01',
    sex: 'FEMALE',
    contacts: [NewPatientContact(type: 'PHONE', value: '3001234567')],
    addresses: [NewPatientAddress(street: 'Calle 1', departmentId: 'dep-1')],
    guardians: [
      NewPatientGuardian(relationship: 'MOTHER', fullName: 'Luisa Gomez'),
    ],
  );

  test('crea paciente local y encola su comando', () async {
    final write = await clinical.createPatient(
      institutionId: 'inst-1',
      input: input,
    );

    final patient = await db.patientLocalById(write.entity.id);
    expect(patient!.documentNumber, '10203040');
    expect(patient.phone, '3001234567');
    expect(patient.syncState, SyncAggregateState.pendingSync.value);

    final guardians = await db.patientGuardiansFor(write.entity.id);
    expect(guardians.single.fullName, 'Luisa Gomez');
    expect(await outbox.pendingCount(), 1);
  });

  test('encadena atencion, dosis y completado con dependencias', () async {
    final patient = await clinical.createPatient(
      institutionId: 'inst-1',
      input: input,
    );
    final attention = await clinical.createAttention(
      institutionId: 'inst-1',
      patientId: patient.entity.id,
      observations: 'Control',
      dependencies: [patient.operationId],
    );
    final dose = await clinical.registerDose(
      attentionId: attention.entity.id,
      vaccineId: 'vac-1',
      doseOptionId: 'dose-1',
      vaccineNameSnapshot: 'BCG',
      dependencies: [attention.operationId],
    );
    await clinical.completeAttention(
      attentionId: attention.entity.id,
      dependencies: [dose.operationId],
    );

    final attentionLocal = await db.attentionLocalById(attention.entity.id);
    expect(attentionLocal!.status, 'COMPLETED');
    expect(
      (await db.appliedDosesLocalByAttention(attention.entity.id)).single
          .vaccineNameSnapshot,
      'BCG',
    );
    expect(await outbox.pendingCount(), 4);

    final doseEntry = await outbox.byOperationId(dose.operationId);
    expect(doseEntry!.operation.dependencies, [attention.operationId]);
  });

  test('fachada de dominio: busca y encadena toda la cadena clinica', () async {
    final patient = await clinical.createPatientLocal(input);
    expect(patient.documentNumber, '10203040');
    expect(patient.fullName, 'Maria Gomez');

    final found = await clinical.findPatients(
      documentType: 'CC',
      documentNumber: '10203040',
    );
    expect(found.single.id, patient.id);

    final attention = await clinical.createAttentionLocal(
      patientId: patient.id,
      observations: 'Control',
    );
    expect(attention.patientId, patient.id);

    final dose = await clinical.registerDoseLocal(
      attentionId: attention.id,
      vaccineId: 'vac-1',
      doseOptionId: 'dose-1',
      vaccineNameSnapshot: 'BCG',
      doseLabelSnapshot: 'Recien nacido',
    );
    expect(dose.vaccineNameSnapshot, 'BCG');

    final completed = await clinical.completeAttentionLocal(
      attentionId: attention.id,
    );
    expect(completed.status, 'COMPLETED');
    expect(completed.doses.single.id, dose.id);
    expect(await outbox.pendingCount(), 4);
  });
}
