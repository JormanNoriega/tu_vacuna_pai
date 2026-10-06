package com.pai.api.patients.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.AuditResourceType;
import com.pai.api.audit.service.AuditService;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.dto.PatientSummaryResponse;
import com.pai.api.patients.dto.UpdatePatientDemographicsRequest;
import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientAddressRepository;
import com.pai.api.patients.repository.PatientAffiliationRepository;
import com.pai.api.patients.repository.PatientContactRepository;
import com.pai.api.patients.repository.PatientDemographicRepository;
import com.pai.api.patients.repository.PatientGuardianRepository;
import com.pai.api.patients.repository.PatientMedicalHistoryRepository;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.patients.repository.PatientSpecialConditionRepository;
import com.pai.api.patients.repository.PatientUserConditionRepository;
import com.pai.api.patients.support.PatientTestFixtures;
import com.pai.api.shared.application.IdempotencyCoordinator;
import com.pai.api.synchronization.service.ProcessedOperationsService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class PatientServiceTest {

  private static final UUID ACTOR_ID = UUID.randomUUID();
  private static final UUID INSTITUTION_ID = UUID.randomUUID();
  private static final String OPERATION_ID = "11111111-1111-1111-1111-111111111111";

  private PatientRepository patients;
  private PatientContactRepository contacts;
  private PatientDemographicRepository demographics;
  private PatientAddressRepository addresses;
  private PatientGuardianRepository guardians;
  private PatientMedicalHistoryRepository medicalHistories;
  private PatientAffiliationRepository affiliations;
  private PatientSpecialConditionRepository specialConditions;
  private PatientUserConditionRepository userConditions;
  private IdentityService identity;
  private DataScope dataScope;
  private AuditService audit;
  private ProcessedOperationsService processedOperations;
  private PatientService service;

  @BeforeEach
  void setUp() {
    patients = mock(PatientRepository.class);
    contacts = mock(PatientContactRepository.class);
    demographics = mock(PatientDemographicRepository.class);
    addresses = mock(PatientAddressRepository.class);
    guardians = mock(PatientGuardianRepository.class);
    medicalHistories = mock(PatientMedicalHistoryRepository.class);
    affiliations = mock(PatientAffiliationRepository.class);
    specialConditions = mock(PatientSpecialConditionRepository.class);
    userConditions = mock(PatientUserConditionRepository.class);
    identity = mock(IdentityService.class);
    dataScope = new DataScope();
    audit = mock(AuditService.class);
    processedOperations = mock(ProcessedOperationsService.class);
    IdempotencyCoordinator coordinator = new IdempotencyCoordinator(audit, processedOperations);
    PatientMapper mapper = new PatientMapper();
    PatientSubEntitiesWriter subEntities = new PatientSubEntitiesWriter(
        contacts,
        demographics,
        addresses,
        guardians,
        medicalHistories,
        affiliations,
        specialConditions,
        userConditions,
        mapper);
    service = new PatientService(patients, identity, dataScope, coordinator, subEntities, mapper);
  }

  private void stubEmptyChildren(UUID patientId) {
    List<UUID> ids = List.of(patientId);
    when(demographics.findByPatientIdIn(ids)).thenReturn(List.of());
    when(contacts.findByPatientIdInOrderByCreatedAtAsc(ids)).thenReturn(List.of());
    when(addresses.findByPatientIdInOrderByCreatedAtAsc(ids)).thenReturn(List.of());
    when(guardians.findByPatientIdInOrderByCreatedAtAsc(ids)).thenReturn(List.of());
    when(medicalHistories.findByPatientIdInOrderByCreatedAtAsc(ids)).thenReturn(List.of());
    when(affiliations.findByPatientIdIn(ids)).thenReturn(List.of());
    when(specialConditions.findByPatientIdIn(ids)).thenReturn(List.of());
    when(userConditions.findByPatientIdIn(ids)).thenReturn(List.of());
  }

  @Test
  void create_normalizesDocumentAndPersistsPatient() {
    when(processedOperations.find(OPERATION_ID, PatientResponse.class))
        .thenReturn(Optional.empty());
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
            INSTITUTION_ID, "CC", "12345678"))
        .thenReturn(false);
    when(patients.save(any(PatientEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));

    PatientResponse response =
        service.create(ACTOR_ID, OPERATION_ID, PatientTestFixtures.request("12.345.678"));

    assertThat(response.documentNumber()).isEqualTo("12345678");
    assertThat(response.institutionId()).isEqualTo(INSTITUTION_ID);
    assertThat(response.sex()).isEqualTo("MALE");

    ArgumentCaptor<PatientEntity> captor = ArgumentCaptor.forClass(PatientEntity.class);
    verify(patients).save(captor.capture());
    assertThat(captor.getValue().getDocumentNumber()).isEqualTo("12345678");
    assertThat(captor.getValue().getInstitutionId()).isEqualTo(INSTITUTION_ID);

    verify(audit)
        .record(argThat(record -> record.actorId().equals(ACTOR_ID)
            && record.institutionId().equals(INSTITUTION_ID)
            && record.action() == AuditAction.PATIENT_CREATED
            && record.resourceType() == AuditResourceType.PATIENT
            && record.clientOperationId().equals(UUID.fromString(OPERATION_ID))));
    verify(processedOperations)
        .record(eq(OPERATION_ID), eq("CREATE_PATIENT"), any(), any(), any(), any());
  }

  @Test
  void create_rejectsDuplicateDocumentInInstitution() {
    when(processedOperations.find(OPERATION_ID, PatientResponse.class))
        .thenReturn(Optional.empty());
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
            INSTITUTION_ID, "CC", "12345678"))
        .thenReturn(true);

    assertThatThrownBy(
            () -> service.create(ACTOR_ID, OPERATION_ID, PatientTestFixtures.request("12345678")))
        .isInstanceOf(PatientAlreadyExistsException.class);
    verify(patients, never()).save(any());
  }

  @Test
  void create_rejectsInvalidDocumentNumberForType() {
    when(processedOperations.find(OPERATION_ID, PatientResponse.class))
        .thenReturn(Optional.empty());
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));

    assertThatThrownBy(
            () -> service.create(ACTOR_ID, OPERATION_ID, PatientTestFixtures.request("12")))
        .isInstanceOf(IllegalArgumentException.class);
    verify(patients, never()).save(any());
  }

  @Test
  void create_requiresGuardianForMinor() {
    when(processedOperations.find(OPERATION_ID, PatientResponse.class))
        .thenReturn(Optional.empty());
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));

    CreatePatientRequest minor =
        PatientTestFixtures.request("12345678", LocalDate.now().minusYears(5));

    assertThatThrownBy(() -> service.create(ACTOR_ID, OPERATION_ID, minor))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessageContaining("tutor");
    verify(patients, never()).save(any());
  }

  @Test
  void create_replaysOriginalResponseForKnownOperationId() {
    PatientResponse original = new PatientResponse(
        UUID.randomUUID(),
        INSTITUTION_ID,
        "CC",
        "12345678",
        "Juan",
        null,
        "Perez",
        null,
        LocalDate.of(2020, 5, 1),
        "MALE",
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        "ACTIVE",
        0,
        Instant.now(),
        Instant.now(),
        null,
        List.of(),
        List.of(),
        List.of(),
        List.of(),
        null,
        null,
        null);
    when(processedOperations.find(OPERATION_ID, PatientResponse.class))
        .thenReturn(Optional.of(original));

    PatientResponse response =
        service.create(ACTOR_ID, OPERATION_ID, PatientTestFixtures.request("99999999"));

    assertThat(response).isEqualTo(original);
    verify(patients, never()).save(any());
    verify(audit, never()).record(any());
  }

  @Test
  void get_rejectsPatientFromOtherInstitution() {
    UUID patientId = UUID.randomUUID();
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.get(ACTOR_ID, patientId))
        .isInstanceOf(PatientNotFoundException.class);
  }

  @Test
  void get_returnsPatientScopedToActorInstitution() {
    UUID patientId = UUID.randomUUID();
    PatientEntity patient = PatientTestFixtures.patient(patientId, INSTITUTION_ID);
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
        .thenReturn(Optional.of(patient));
    stubEmptyChildren(patientId);

    PatientResponse response = service.get(ACTOR_ID, patientId);

    assertThat(response.id()).isEqualTo(patientId);
    assertThat(response.documentNumber()).isEqualTo("12345678");
  }

  @Test
  void search_normalizesNumberAndScopesByInstitution() {
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    UUID patientId = UUID.randomUUID();
    PatientEntity patient = PatientTestFixtures.patient(patientId, INSTITUTION_ID);
    when(patients.findByInstitutionIdAndDocumentTypeAndDocumentNumber(
            INSTITUTION_ID, "CC", "12345678"))
        .thenReturn(Optional.of(patient));

    List<PatientSummaryResponse> result = service.search(ACTOR_ID, "cc", "12.345.678");

    assertThat(result).hasSize(1);
    assertThat(result.get(0).documentNumber()).isEqualTo("12345678");
  }

  @Test
  void updateDemographics_normalizesGenderAndPersists() {
    UUID patientId = UUID.randomUUID();
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
        .thenReturn(Optional.of(PatientTestFixtures.patient(patientId, INSTITUTION_ID)));
    when(demographics.findByPatientId(patientId)).thenReturn(Optional.empty());
    stubEmptyChildren(patientId);

    service.updateDemographics(
        ACTOR_ID, patientId, new UpdatePatientDemographicsRequest("female", "Mestiza", "Primaria"));

    ArgumentCaptor<PatientDemographicEntity> captor =
        ArgumentCaptor.forClass(PatientDemographicEntity.class);
    verify(demographics).save(captor.capture());
    assertThat(captor.getValue().getGender()).isEqualTo("FEMALE");
    assertThat(captor.getValue().getEthnicity()).isEqualTo("Mestiza");
    verify(audit)
        .record(argThat(record -> record.actorId().equals(ACTOR_ID)
            && record.institutionId().equals(INSTITUTION_ID)
            && record.action() == AuditAction.PATIENT_DEMOGRAPHICS_UPDATED
            && record.resourceType() == AuditResourceType.PATIENT
            && record.resourceId().equals(patientId)));
  }

  @Test
  void updateDemographics_rejectsInvalidGender() {
    UUID patientId = UUID.randomUUID();
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
        .thenReturn(Optional.of(PatientTestFixtures.patient(patientId, INSTITUTION_ID)));

    assertThatThrownBy(() -> service.updateDemographics(
            ACTOR_ID, patientId, new UpdatePatientDemographicsRequest("X", null, null)))
        .isInstanceOf(IllegalArgumentException.class);
    verify(demographics, never()).save(any());
  }

  @Test
  void updateMedicalHistories_replacesList() {
    UUID patientId = UUID.randomUUID();
    when(identity.resolve(ACTOR_ID))
        .thenReturn(PatientTestFixtures.vaccinator(ACTOR_ID, INSTITUTION_ID));
    when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
        .thenReturn(Optional.of(PatientTestFixtures.patient(patientId, INSTITUTION_ID)));
    stubEmptyChildren(patientId);

    service.updateMedicalHistories(
        ACTOR_ID,
        patientId,
        new UpdatePatientMedicalHistoriesRequest(
            List.of(new UpdatePatientMedicalHistoriesRequest.MedicalHistoryDto(
                "Asma", LocalDate.of(2020, 1, 1), null, null, null, null, null, null, null))));

    verify(medicalHistories).deleteByPatientId(patientId);
    verify(medicalHistories).save(any(PatientMedicalHistoryEntity.class));
    verify(audit)
        .record(argThat(record -> record.actorId().equals(ACTOR_ID)
            && record.institutionId().equals(INSTITUTION_ID)
            && record.action() == AuditAction.PATIENT_HISTORY_UPDATED
            && record.resourceType() == AuditResourceType.PATIENT
            && record.resourceId().equals(patientId)));
  }
}
