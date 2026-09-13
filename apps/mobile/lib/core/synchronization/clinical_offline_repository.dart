import 'package:drift/drift.dart' show Value;

import '../storage/app_database.dart';
import '../utils/uuid.dart';
import 'command_payloads.dart';
import 'sync_operation.dart';
import 'sync_outbox.dart';
import 'sync_status.dart';
import '../../features/attentions/domain/entities/attention.dart';
import '../../features/patients/domain/entities/new_patient.dart';
import '../../features/patients/domain/entities/patient.dart';

/// Resultado de una escritura clinica local: la entidad persistida y la
/// operacion encolada (para encadenar dependencias).
class ClinicalWrite<T> {
  const ClinicalWrite({required this.entity, required this.operationId});

  final T entity;
  final String operationId;
}

/// Repositorio local-first del flujo clinico offline (Fase 1).
///
/// Escribe el agregado en el working set local y encola su comando en el
/// outbox de forma atomica. No requiere red ni token: la sincronizacion la
/// resuelve despues el [SyncEngine].
///
/// Los repositorios online existentes (`patients_repository_impl`,
/// `attentions_repository_impl`) se mantienen para los caminos online-first;
/// este repositorio es el que consumira el wizard offline.
class ClinicalOfflineRepository {
  ClinicalOfflineRepository({
    required AppDatabase database,
    required SyncOutboxRepository outboxRepository,
  }) : _db = database,
       _outbox = outboxRepository;

  final AppDatabase _db;
  final SyncOutboxRepository _outbox;

  Future<ClinicalWrite<PatientsLocalData>> createPatient({
    required String institutionId,
    required NewPatientInput input,
  }) async {
    final patientId = uuidV4();
    final operation = SyncOperation(
      operationId: uuidV4(),
      commandType: SyncCommandType.createPatient,
      aggregateId: patientId,
      payload: CommandPayloads.createPatient(input),
    );

    await _outbox.commitLocalWrite(
      writeLocal: () async {
        await _db.upsertPatientLocal(_patientCompanion(institutionId, patientId, input));
        final guardians = input.guardians;
        if (guardians.isNotEmpty) {
          await _db.replacePatientGuardiansLocal(patientId, [
            for (final guardian in guardians)
              PatientGuardiansLocalCompanion.insert(
                id: uuidV4(),
                patientId: patientId,
                fullName: guardian.fullName,
                relationship: guardian.relationship,
                phone: Value(guardian.phone),
              ),
          ]);
        }
      },
      operation: operation,
    );

    final entity = await _db.patientLocalById(patientId);
    return ClinicalWrite(entity: entity!, operationId: operation.operationId);
  }

  Future<ClinicalWrite<AttentionsLocalData>> createAttention({
    required String institutionId,
    required String patientId,
    String? attentionDate,
    String? observations,
    List<String> dependencies = const [],
  }) async {
    final attentionId = uuidV4();
    final operation = SyncOperation(
      operationId: uuidV4(),
      commandType: SyncCommandType.createAttention,
      aggregateId: attentionId,
      payload: CommandPayloads.createAttention(
        patientId: patientId,
        attentionDate: attentionDate,
        observations: observations,
      ),
      dependencies: dependencies,
    );

    await _outbox.commitLocalWrite(
      writeLocal: () => _db.upsertAttentionLocal(
        AttentionsLocalCompanion.insert(
          id: attentionId,
          institutionId: institutionId,
          patientId: patientId,
          status: 'DRAFT',
          attentionDate: Value(_epoch(attentionDate)),
          observations: Value(observations),
          version: 0,
          syncState: SyncAggregateState.pendingSync.value,
          updatedAt: _epochNow(),
        ),
      ),
      operation: operation,
    );

    final entity = await _db.attentionLocalById(attentionId);
    return ClinicalWrite(entity: entity!, operationId: operation.operationId);
  }

  Future<ClinicalWrite<AppliedDosesLocalData>> registerDose({
    required String attentionId,
    required String vaccineId,
    required String doseOptionId,
    required String vaccineNameSnapshot,
    String? pneumococcalTypeOptionId,
    String? doseLabelSnapshot,
    String? lotNumber,
    String? applicationDate,
    String? selectedLaboratoryId,
    String? selectedSyringeId,
    String? selectedDropperId,
    String? selectedObservationId,
    List<String> dependencies = const [],
  }) async {
    final doseId = uuidV4();
    final operation = SyncOperation(
      operationId: uuidV4(),
      commandType: SyncCommandType.registerAppliedDose,
      aggregateId: doseId,
      payload: CommandPayloads.registerAppliedDose(
        attentionId: attentionId,
        vaccineId: vaccineId,
        doseOptionId: doseOptionId,
        pneumococcalTypeOptionId: pneumococcalTypeOptionId,
        lotNumber: lotNumber,
        applicationDate: applicationDate,
        selectedLaboratoryId: selectedLaboratoryId,
        selectedSyringeId: selectedSyringeId,
        selectedDropperId: selectedDropperId,
        selectedObservationId: selectedObservationId,
      ),
      dependencies: dependencies,
    );

    await _outbox.commitLocalWrite(
      writeLocal: () => _db.upsertAppliedDoseLocal(
        AppliedDosesLocalCompanion.insert(
          id: doseId,
          attentionId: attentionId,
          vaccineId: Value(vaccineId),
          status: 'REGISTERED',
          appliedAt: _epoch(applicationDate) ?? _epochNow(),
          vaccineNameSnapshot: vaccineNameSnapshot,
          doseLabelSnapshot: Value(doseLabelSnapshot),
          syncState: SyncAggregateState.pendingSync.value,
          updatedAt: _epochNow(),
        ),
      ),
      operation: operation,
    );

    final entity = await _db.appliedDoseLocalById(doseId);
    return ClinicalWrite(entity: entity!, operationId: operation.operationId);
  }

  Future<ClinicalWrite<AttentionsLocalData>> completeAttention({
    required String attentionId,
    List<String> dependencies = const [],
  }) async {
    final operation = SyncOperation(
      operationId: uuidV4(),
      commandType: SyncCommandType.completeAttention,
      aggregateId: attentionId,
      payload: CommandPayloads.completeAttention,
      dependencies: dependencies,
    );

    await _outbox.commitLocalWrite(
      writeLocal: () => _db.updateAttentionSyncState(
        attentionId,
        SyncAggregateState.pendingSync.value,
        status: 'COMPLETED',
      ),
      operation: operation,
    );

    final entity = await _db.attentionLocalById(attentionId);
    return ClinicalWrite(entity: entity!, operationId: operation.operationId);
  }

  // ---------------------------------------------------------------------------
  // Fachada de dominio (lectura/escritura tipada para controladores offline).
  //
  // Los metodos anteriores devuelven filas Drift; estos devuelven entidades de
  // dominio listas para la UI. La institucion se resuelve del perfil local
  // (nunca del cliente), igual que en el backend.
  // ---------------------------------------------------------------------------

  Future<String> _institutionId() async {
    final profile = await _db.currentUserProfile();
    return profile?.institutionId ?? '';
  }

  /// Busca pacientes en el working set local. Con documento filtra exacto;
  /// sin documento devuelve los del scope institucional.
  Future<List<Patient>> findPatients({
    String? documentType,
    String? documentNumber,
  }) async {
    final institutionId = await _institutionId();
    if (institutionId.isEmpty) return const [];
    final rows = (documentType != null && documentNumber != null)
        ? await _db.searchPatientsLocal(
            institutionId: institutionId,
            documentType: documentType,
            documentNumber: documentNumber,
          )
        : await _db.patientsLocalByInstitution(institutionId);
    return rows.map(_toPatient).toList();
  }

  Future<Patient> createPatientLocal(NewPatientInput input) async {
    final write = await createPatient(
      institutionId: await _institutionId(),
      input: input,
    );
    return _toPatient(write.entity);
  }

  Future<Attention> createAttentionLocal({
    required String patientId,
    String? attentionDate,
    String? observations,
    List<String> dependencies = const [],
  }) async {
    final write = await createAttention(
      institutionId: await _institutionId(),
      patientId: patientId,
      attentionDate: attentionDate,
      observations: observations,
      dependencies: dependencies,
    );
    return _toAttention(write.entity);
  }

  Future<AppliedDose> registerDoseLocal({
    required String attentionId,
    required String vaccineId,
    required String doseOptionId,
    required String vaccineNameSnapshot,
    String? pneumococcalTypeOptionId,
    String? doseLabelSnapshot,
    String? lotNumber,
    String? applicationDate,
    String? selectedLaboratoryId,
    String? selectedSyringeId,
    String? selectedDropperId,
    String? selectedObservationId,
    List<String> dependencies = const [],
  }) async {
    final write = await registerDose(
      attentionId: attentionId,
      vaccineId: vaccineId,
      doseOptionId: doseOptionId,
      vaccineNameSnapshot: vaccineNameSnapshot,
      pneumococcalTypeOptionId: pneumococcalTypeOptionId,
      doseLabelSnapshot: doseLabelSnapshot,
      lotNumber: lotNumber,
      applicationDate: applicationDate,
      selectedLaboratoryId: selectedLaboratoryId,
      selectedSyringeId: selectedSyringeId,
      selectedDropperId: selectedDropperId,
      selectedObservationId: selectedObservationId,
      dependencies: dependencies,
    );
    return _toDose(write.entity);
  }

  Future<Attention> completeAttentionLocal({
    required String attentionId,
    List<String> dependencies = const [],
  }) async {
    await completeAttention(
      attentionId: attentionId,
      dependencies: dependencies,
    );
    return attentionLocalWithDoses(attentionId);
  }

  Future<Attention> attentionLocalWithDoses(String attentionId) async {
    final attention = await _db.attentionLocalById(attentionId);
    if (attention == null) {
      throw StateError('Atencion local no encontrada: $attentionId');
    }
    final doseRows = await _db.appliedDosesLocalByAttention(attentionId);
    return _toAttention(attention, doseRows.map(_toDose).toList());
  }

  Patient _toPatient(PatientsLocalData row) => Patient(
    id: row.id,
    documentType: row.documentType,
    documentNumber: row.documentNumber,
    firstName: row.firstName,
    lastName: row.lastName,
    birthDate: row.birthDate,
    sex: row.sex ?? '',
    status: 'ACTIVE',
  );

  Attention _toAttention(
    AttentionsLocalData row, [
    List<AppliedDose> doses = const [],
  ]) => Attention(
    id: row.id,
    patientId: row.patientId,
    professionalId: row.vaccinatorId ?? '',
    status: row.status,
    version: row.version,
    doses: doses,
    attentionDate: _fromEpoch(row.attentionDate),
    observations: row.observations,
  );

  AppliedDose _toDose(AppliedDosesLocalData row) => AppliedDose(
    id: row.id,
    attentionId: row.attentionId,
    vaccineId: row.vaccineId ?? '',
    vaccineNameSnapshot: row.vaccineNameSnapshot,
    vaccineCodeSnapshot: '',
    doseLabelSnapshot: row.doseLabelSnapshot ?? '',
    status: row.status,
    lotNumber: row.lot,
    applicationDate: _fromEpoch(row.appliedAt),
    catalogVersion: row.catalogVersion ?? 0,
  );

  static DateTime? _fromEpoch(int? epoch) => epoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);

  PatientsLocalCompanion _patientCompanion(
    String institutionId,
    String patientId,
    NewPatientInput input,
  ) {
    final phone = _firstContact(input.contacts, 'PHONE');
    final email = _firstContact(input.contacts, 'EMAIL');
    final address = _firstAddress(input.addresses);
    return PatientsLocalCompanion.insert(
      id: patientId,
      institutionId: institutionId,
      documentType: input.documentType,
      documentNumber: input.documentNumber,
      firstName: input.firstName,
      lastName: input.lastName,
      birthDate: Value(DateTime.tryParse(input.birthDate)),
      sex: Value(input.sex),
      gender: Value(input.demographics?.gender),
      phone: Value(phone),
      email: Value(email),
      addressLine: Value(address?.street),
      addressDepartment: Value(address?.departmentId),
      addressMunicipality: Value(address?.municipalityId),
      syncState: SyncAggregateState.pendingSync.value,
      version: 0,
      updatedAt: _epochNow(),
    );
  }

  static String? _firstContact(
    List<NewPatientContact> contacts,
    String type,
  ) {
    for (final contact in contacts) {
      if (contact.type == type && contact.value.isNotEmpty) {
        return contact.value;
      }
    }
    return null;
  }

  static NewPatientAddress? _firstAddress(List<NewPatientAddress> addresses) {
    for (final address in addresses) {
      if (!address.isEmpty) return address;
    }
    return null;
  }

  static int _epochNow() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  static int? _epoch(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : parsed.toUtc().millisecondsSinceEpoch ~/ 1000;
  }
}
