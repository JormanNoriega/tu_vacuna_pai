package com.pai.api.patients.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.service.AuditService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.dto.UpdatePatientDemographicsRequest;
import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientAddressRepository;
import com.pai.api.patients.repository.PatientContactRepository;
import com.pai.api.patients.repository.PatientDemographicRepository;
import com.pai.api.patients.repository.PatientGuardianRepository;
import com.pai.api.patients.repository.PatientMedicalHistoryRepository;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.synchronization.service.ProcessedOperationsService;

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
        identity = mock(IdentityService.class);
        dataScope = new DataScope();
        audit = mock(AuditService.class);
        processedOperations = mock(ProcessedOperationsService.class);
        service = new PatientService(patients, contacts, demographics, addresses,
            guardians, medicalHistories, identity, dataScope, audit, processedOperations);
    }

    private InstitutionEntity institution() {
        return new InstitutionEntity(INSTITUTION_ID, "HOSP-A", "Hospital A",
            InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    }

    private AuthorizedUser vaccinatorActor() {
        return new AuthorizedUser(ACTOR_ID, "vac@hosp.a", "Ana Vacunadora",
            institution(), List.of("VACCINATOR"),
            List.of("PATIENT_READ", "PATIENT_WRITE"), Instant.now());
    }

    private CreatePatientRequest request(String documentNumber) {
        return new CreatePatientRequest("CC", documentNumber, "Juan", "Perez",
            LocalDate.of(2020, 5, 1), "MALE", null, null, null, null, null);
    }

    private PatientEntity patient(UUID id) {
        return new PatientEntity(id, INSTITUTION_ID, "CC", "12345678", "Juan",
            "Perez", LocalDate.of(2020, 5, 1), PatientEntity.Sex.MALE, Instant.now());
    }

    private void stubEmptyChildren(UUID patientId) {
        when(demographics.findByPatientId(patientId)).thenReturn(Optional.empty());
        when(contacts.findByPatientIdOrderByCreatedAtAsc(patientId)).thenReturn(List.of());
        when(addresses.findByPatientIdOrderByCreatedAtAsc(patientId)).thenReturn(List.of());
        when(guardians.findByPatientIdOrderByCreatedAtAsc(patientId)).thenReturn(List.of());
        when(medicalHistories.findByPatientIdOrderByCreatedAtAsc(patientId))
            .thenReturn(List.of());
    }

    @Test
    void create_normalizesDocumentAndPersistsPatient() {
        when(processedOperations.find(OPERATION_ID, PatientResponse.class))
            .thenReturn(Optional.empty());
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
            INSTITUTION_ID, "CC", "12345678")).thenReturn(false);
        when(patients.save(any(PatientEntity.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));

        PatientResponse response = service.create(ACTOR_ID, OPERATION_ID,
            request("12.345.678"));

        assertThat(response.documentNumber()).isEqualTo("12345678");
        assertThat(response.institutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(response.sex()).isEqualTo("MALE");

        ArgumentCaptor<PatientEntity> captor = ArgumentCaptor.forClass(PatientEntity.class);
        verify(patients).save(captor.capture());
        assertThat(captor.getValue().getDocumentNumber()).isEqualTo("12345678");
        assertThat(captor.getValue().getInstitutionId()).isEqualTo(INSTITUTION_ID);

        verify(audit).record(eq(ACTOR_ID), eq(INSTITUTION_ID),
            eq(AuditAction.PATIENT_CREATED), eq("PATIENT"), any(),
            eq(UUID.fromString(OPERATION_ID)), any());
        verify(processedOperations).record(eq(OPERATION_ID), eq("CREATE_PATIENT"),
            any(), any());
    }

    @Test
    void create_rejectsDuplicateDocumentInInstitution() {
        when(processedOperations.find(OPERATION_ID, PatientResponse.class))
            .thenReturn(Optional.empty());
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
            INSTITUTION_ID, "CC", "12345678")).thenReturn(true);

        assertThatThrownBy(() -> service.create(ACTOR_ID, OPERATION_ID, request("12345678")))
            .isInstanceOf(PatientAlreadyExistsException.class);
        verify(patients, never()).save(any());
    }

    @Test
    void create_rejectsInvalidDocumentNumberForType() {
        when(processedOperations.find(OPERATION_ID, PatientResponse.class))
            .thenReturn(Optional.empty());
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());

        assertThatThrownBy(() -> service.create(ACTOR_ID, OPERATION_ID, request("12")))
            .isInstanceOf(IllegalArgumentException.class);
        verify(patients, never()).save(any());
    }

    @Test
    void create_replaysOriginalResponseForKnownOperationId() {
        PatientResponse original = new PatientResponse(
            UUID.randomUUID(), INSTITUTION_ID, "CC", "12345678", "Juan", "Perez",
            LocalDate.of(2020, 5, 1), "MALE", "ACTIVE", 0, Instant.now(), Instant.now(),
            null, List.of(), List.of(), List.of(), List.of());
        when(processedOperations.find(OPERATION_ID, PatientResponse.class))
            .thenReturn(Optional.of(original));

        PatientResponse response = service.create(ACTOR_ID, OPERATION_ID,
            request("99999999"));

        assertThat(response).isEqualTo(original);
        verify(identity, never()).resolve(any());
        verify(patients, never()).save(any());
    }

    @Test
    void get_rejectsPatientFromOtherInstitution() {
        UUID patientId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
            .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(ACTOR_ID, patientId))
            .isInstanceOf(PatientNotFoundException.class);
    }

    @Test
    void get_returnsPatientScopedToActorInstitution() {
        UUID patientId = UUID.randomUUID();
        PatientEntity patient = new PatientEntity(patientId, INSTITUTION_ID, "CC",
            "12345678", "Juan", "Perez", LocalDate.of(2020, 5, 1),
            PatientEntity.Sex.MALE, Instant.now());
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
            .thenReturn(Optional.of(patient));
        stubEmptyChildren(patientId);

        PatientResponse response = service.get(ACTOR_ID, patientId);

        assertThat(response.id()).isEqualTo(patientId);
        assertThat(response.documentNumber()).isEqualTo("12345678");
    }

    @Test
    void search_normalizesNumberAndScopesByInstitution() {
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        UUID patientId = UUID.randomUUID();
        PatientEntity patient = new PatientEntity(patientId, INSTITUTION_ID, "CC",
            "12345678", "Juan", "Perez", LocalDate.of(2020, 5, 1),
            PatientEntity.Sex.MALE, Instant.now());
        when(patients.findByInstitutionIdAndDocumentTypeAndDocumentNumber(
            INSTITUTION_ID, "CC", "12345678")).thenReturn(Optional.of(patient));
        stubEmptyChildren(patientId);

        List<PatientResponse> result = service.search(ACTOR_ID, "cc", "12.345.678");

        assertThat(result).hasSize(1);
        assertThat(result.get(0).documentNumber()).isEqualTo("12345678");
    }

    @Test
    void updateDemographics_normalizesGenderAndPersists() {
        UUID patientId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
            .thenReturn(Optional.of(patient(patientId)));
        when(demographics.findByPatientId(patientId)).thenReturn(Optional.empty());
        stubEmptyChildren(patientId);

        service.updateDemographics(ACTOR_ID, patientId,
            new UpdatePatientDemographicsRequest("female", "Mestiza", "Primaria"));

        ArgumentCaptor<PatientDemographicEntity> captor =
            ArgumentCaptor.forClass(PatientDemographicEntity.class);
        verify(demographics).save(captor.capture());
        assertThat(captor.getValue().getGender()).isEqualTo("FEMALE");
        assertThat(captor.getValue().getEthnicity()).isEqualTo("Mestiza");
        verify(audit).record(eq(ACTOR_ID), eq(INSTITUTION_ID),
            eq(AuditAction.PATIENT_DEMOGRAPHICS_UPDATED), eq("PATIENT"),
            eq(patientId), any(), any());
    }

    @Test
    void updateDemographics_rejectsInvalidGender() {
        UUID patientId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
            .thenReturn(Optional.of(patient(patientId)));

        assertThatThrownBy(() -> service.updateDemographics(ACTOR_ID, patientId,
            new UpdatePatientDemographicsRequest("X", null, null)))
            .isInstanceOf(IllegalArgumentException.class);
        verify(demographics, never()).save(any());
    }

    @Test
    void updateMedicalHistories_replacesList() {
        UUID patientId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(vaccinatorActor());
        when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
            .thenReturn(Optional.of(patient(patientId)));
        stubEmptyChildren(patientId);

        service.updateMedicalHistories(ACTOR_ID, patientId,
            new UpdatePatientMedicalHistoriesRequest(List.of(
                new UpdatePatientMedicalHistoriesRequest.MedicalHistoryDto(
                    "Asma", LocalDate.of(2020, 1, 1), null))));

        verify(medicalHistories).deleteByPatientId(patientId);
        verify(medicalHistories).save(any(PatientMedicalHistoryEntity.class));
        verify(audit).record(eq(ACTOR_ID), eq(INSTITUTION_ID),
            eq(AuditAction.PATIENT_HISTORY_UPDATED), eq("PATIENT"),
            eq(patientId), any(), any());
    }
}
