package com.pai.api.synchronization.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.attentions.dto.AttentionResponse;
import com.pai.api.attentions.dto.CreateAttentionRequest;
import com.pai.api.attentions.service.AttentionService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.patients.service.PatientService;
import com.pai.api.synchronization.dto.RejectedOperation;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.dto.SyncPushRequest;
import com.pai.api.synchronization.dto.SyncPushResponse;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class SyncPushServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID PATIENT_ID = UUID.randomUUID();

    private PatientService patients;
    private AttentionService attentions;
    private PatientMergeRequestService mergeRequests;
    private IdentityService identity;
    private ProcessedOperationsService processedOperations;
    private SyncPushService service;

    @BeforeEach
    void setUp() {
        patients = mock(PatientService.class);
        attentions = mock(AttentionService.class);
        mergeRequests = mock(PatientMergeRequestService.class);
        identity = mock(IdentityService.class);
        processedOperations = mock(ProcessedOperationsService.class);
        service = new SyncPushService(
                patients, attentions, mergeRequests, identity, processedOperations, new ObjectMapper());
    }

    private InstitutionEntity institution() {
        return new InstitutionEntity(
                INSTITUTION_ID,
                "HOSP-A",
                "Hospital A",
                InstitutionEntity.Status.ACTIVE,
                (short) 72,
                Instant.now(),
                Instant.now());
    }

    private AuthorizedUser actor(String... permissions) {
        return new AuthorizedUser(
                ACTOR_ID,
                "vac@hosp.a",
                "Ana Vacunadora",
                institution(),
                List.of("VACCINATOR"),
                List.of(permissions),
                Instant.now());
    }

    private SyncOperation patientOperation(UUID operationId, List<UUID> dependencies) {
        return new SyncOperation(
                operationId,
                "CREATE_PATIENT",
                UUID.randomUUID(),
                Map.of(
                        "documentType", "CC",
                        "documentNumber", "12345678",
                        "firstName", "Juan",
                        "lastName", "Perez",
                        "birthDate", "2020-05-01",
                        "sex", "MALE"),
                dependencies);
    }

    private SyncOperation attentionOperation(UUID operationId, UUID aggregateId, List<UUID> dependencies) {
        return new SyncOperation(
                operationId,
                "CREATE_ATTENTION",
                aggregateId,
                Map.of("patientId", PATIENT_ID.toString()),
                dependencies);
    }

    @Test
    void rejects_operation_without_accepted_dependency() {
        UUID dependencyId = UUID.randomUUID();
        UUID operationId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("ATTENTION_CREATE"));
        when(processedOperations.exists(dependencyId.toString())).thenReturn(false);

        SyncPushResponse response = service.push(
                ACTOR_ID,
                new SyncPushRequest(List.of(attentionOperation(operationId, UUID.randomUUID(), List.of(dependencyId)))));

        assertThat(response.accepted()).isEmpty();
        assertThat(response.rejected())
                .singleElement()
                .extracting(RejectedOperation::reason)
                .isEqualTo("DEPENDENCY_NOT_FOUND");
        verify(attentions, never()).create(any(), anyString(), any(CreateAttentionRequest.class));
    }

    @Test
    void rejects_dependent_operation_when_dependency_failed() {
        UUID patientOp = UUID.randomUUID();
        UUID attentionOp = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("PATIENT_WRITE", "ATTENTION_CREATE"));
        when(processedOperations.exists(anyString())).thenReturn(false);
        when(patients.create(eq(ACTOR_ID), eq(patientOp.toString()), any(), any()))
                .thenThrow(new PatientAlreadyExistsException("Duplicado", UUID.randomUUID()));

        SyncPushResponse response = service.push(
                ACTOR_ID,
                new SyncPushRequest(List.of(
                        patientOperation(patientOp, List.of()),
                        attentionOperation(attentionOp, UUID.randomUUID(), List.of(patientOp)))));

        assertThat(response.accepted()).isEmpty();
        assertThat(response.rejected())
                .extracting(RejectedOperation::reason)
                .containsExactly("DUPLICATE_BUSINESS_IDENTITY", "DEPENDENCY_FAILED");
    }

    @Test
    void replays_same_operation_id_returns_original_response() {
        UUID operationId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("PATIENT_WRITE"));
        when(processedOperations.exists(operationId.toString())).thenReturn(true);

        SyncPushResponse response =
                service.push(ACTOR_ID, new SyncPushRequest(List.of(patientOperation(operationId, List.of()))));

        assertThat(response.accepted()).containsExactly(operationId);
        assertThat(response.rejected()).isEmpty();
        verify(patients, never()).create(any(), anyString(), any());
    }

    @Test
    void never_duplicates_attention_on_retry() {
        UUID operationId = UUID.randomUUID();
        UUID aggregateId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("ATTENTION_CREATE"));
        when(processedOperations.exists(operationId.toString())).thenReturn(false, true);
        when(attentions.create(eq(ACTOR_ID), eq(operationId.toString()), any(), any()))
                .thenReturn(mock(AttentionResponse.class));

        SyncOperation operation = attentionOperation(operationId, aggregateId, List.of());
        service.push(ACTOR_ID, new SyncPushRequest(List.of(operation)));
        service.push(ACTOR_ID, new SyncPushRequest(List.of(operation)));

        verify(attentions, times(1)).create(eq(ACTOR_ID), eq(operationId.toString()), any(), any());
    }

    @Test
    void duplicate_patient_creates_pending_merge_request() {
        UUID operationId = UUID.randomUUID();
        UUID existingPatientId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("PATIENT_WRITE"));
        when(processedOperations.exists(anyString())).thenReturn(false);
        when(patients.create(eq(ACTOR_ID), eq(operationId.toString()), any(), any()))
                .thenThrow(new PatientAlreadyExistsException("Duplicado", existingPatientId));

        SyncPushResponse response =
                service.push(ACTOR_ID, new SyncPushRequest(List.of(patientOperation(operationId, List.of()))));

        assertThat(response.rejected())
                .singleElement()
                .extracting(RejectedOperation::reason)
                .isEqualTo("DUPLICATE_BUSINESS_IDENTITY");
        verify(mergeRequests).requestReview(existingPatientId);
    }

    @Test
    void permission_denied_rejects_operation() {
        UUID operationId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("PATIENT_WRITE"));

        SyncPushResponse response = service.push(
                ACTOR_ID,
                new SyncPushRequest(List.of(attentionOperation(operationId, UUID.randomUUID(), List.of()))));

        assertThat(response.rejected())
                .singleElement()
                .extracting(RejectedOperation::reason)
                .isEqualTo("PERMISSION_DENIED");
        verify(attentions, never()).create(any(), anyString(), any());
    }

    @Test
    void honors_client_aggregate_id_as_entity_id() {
        UUID operationId = UUID.randomUUID();
        UUID aggregateId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("PATIENT_WRITE"));
        when(processedOperations.exists(anyString())).thenReturn(false);

        SyncPushResponse response = service.push(
                ACTOR_ID,
                new SyncPushRequest(List.of(new SyncOperation(
                        operationId,
                        "CREATE_PATIENT",
                        aggregateId,
                        Map.of(
                                "documentType", "CC",
                                "documentNumber", "12345678",
                                "firstName", "Juan",
                                "lastName", "Perez",
                                "birthDate", "2020-05-01",
                                "sex", "MALE"),
                        List.of()))));

        assertThat(response.accepted()).containsExactly(operationId);
        verify(patients).create(eq(ACTOR_ID), eq(operationId.toString()), eq(aggregateId), any());
    }

    @Test
    void rejects_unsupported_command_as_invalid_payload() {
        UUID operationId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor("PATIENT_WRITE", "ATTENTION_CREATE"));
        when(processedOperations.exists(anyString())).thenReturn(false);

        SyncPushResponse response = service.push(
                ACTOR_ID,
                new SyncPushRequest(List.of(new SyncOperation(
                        operationId, "UPDATE_ATTENTION", UUID.randomUUID(), Map.of(), List.of()))));

        assertThat(response.rejected())
                .singleElement()
                .extracting(RejectedOperation::reason)
                .isEqualTo("INVALID_PAYLOAD");
    }
}
