package com.pai.api.attentions.service;

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

import com.pai.api.attentions.dto.AttentionResponse;
import com.pai.api.attentions.dto.CancelDoseRequest;
import com.pai.api.attentions.dto.CreateAttentionRequest;
import com.pai.api.attentions.dto.RegisterDoseRequest;
import com.pai.api.attentions.dto.UpdateAttentionRequest;
import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.exception.AttentionNotFoundException;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.audit.AuditAction;
import com.pai.api.audit.service.AuditService;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.synchronization.service.ProcessedOperationsService;

class AttentionServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID PATIENT_ID = UUID.randomUUID();
    private static final String OPERATION_ID = "22222222-2222-2222-2222-222222222222";

    private AttentionRepository attentions;
    private AppliedDoseRepository doses;
    private PatientRepository patients;
    private VaccineRepository vaccines;
    private VaccineOptionRepository vaccineOptions;
    private InstitutionVaccineRepository institutionVaccines;
    private InstitutionVaccineOptionRepository institutionOptions;
    private IdentityService identity;
    private DataScope dataScope;
    private AuditService audit;
    private ProcessedOperationsService processedOperations;
    private AttentionService service;

    @BeforeEach
    void setUp() {
        attentions = mock(AttentionRepository.class);
        doses = mock(AppliedDoseRepository.class);
        patients = mock(PatientRepository.class);
        vaccines = mock(VaccineRepository.class);
        vaccineOptions = mock(VaccineOptionRepository.class);
        institutionVaccines = mock(InstitutionVaccineRepository.class);
        institutionOptions = mock(InstitutionVaccineOptionRepository.class);
        identity = mock(IdentityService.class);
        dataScope = new DataScope();
        audit = mock(AuditService.class);
        processedOperations = mock(ProcessedOperationsService.class);
        service = new AttentionService(attentions, doses, patients, vaccines,
            vaccineOptions, institutionVaccines, institutionOptions, identity, dataScope,
            audit, processedOperations);
    }

    private InstitutionEntity institution() {
        return new InstitutionEntity(INSTITUTION_ID, "HOSP-A", "Hospital A",
            InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    }

    private AuthorizedUser actor() {
        return new AuthorizedUser(ACTOR_ID, "vac@hosp.a", "Ana Vacunadora",
            institution(), List.of("VACCINATOR"),
            List.of("ATTENTION_CREATE", "ATTENTION_READ", "PATIENT_READ"), Instant.now());
    }

    private AttentionEntity attention(AttentionEntity.Status status) {
        AttentionEntity attention = new AttentionEntity(UUID.randomUUID(), PATIENT_ID,
            ACTOR_ID, INSTITUTION_ID, Instant.now(), 1L, null, Instant.now());
        if (status == AttentionEntity.Status.COMPLETED) {
            attention.complete(Instant.now());
        } else if (status == AttentionEntity.Status.CANCELLED) {
            attention.cancel(Instant.now());
        }
        return attention;
    }

    private AppliedDoseEntity dose(UUID attentionId) {
        return new AppliedDoseEntity(UUID.randomUUID(), attentionId, UUID.randomUUID(),
            null, null, Instant.now(), null, null, "Influenza", "INF", "Primera dosis",
            "1", null, 3L, null, null, null, null, null, null, null, null, Instant.now());
    }

    @Test
    void create_assignsConsecutiveDraftAndAudits() {
        UUID patientId = PATIENT_ID;
        when(processedOperations.find(OPERATION_ID, AttentionResponse.class))
            .thenReturn(Optional.empty());
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(patients.findByIdAndInstitutionId(patientId, INSTITUTION_ID))
            .thenReturn(Optional.of(mock(PatientEntity.class)));
        when(attentions.maxConsecutive(INSTITUTION_ID)).thenReturn(4L);
        when(attentions.save(any(AttentionEntity.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));

        AttentionResponse response = service.create(ACTOR_ID, OPERATION_ID,
            new CreateAttentionRequest(patientId, null, "Control") );

        assertThat(response.status()).isEqualTo("DRAFT");
        assertThat(response.consecutive()).isEqualTo(5L);
        assertThat(response.institutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(response.professionalId()).isEqualTo(ACTOR_ID);
        verify(audit).record(eq(ACTOR_ID), eq(INSTITUTION_ID),
            eq(AuditAction.ATTENTION_CREATED), eq("ATTENTION"), any(), any(), any());
        verify(processedOperations).record(eq(OPERATION_ID), eq("CREATE_ATTENTION"),
            any(), any());
    }

    @Test
    void update_rejectsCompletedAttention() {
        AttentionEntity completed = attention(AttentionEntity.Status.COMPLETED);
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(attentions.findByIdAndInstitutionId(completed.getId(), INSTITUTION_ID))
            .thenReturn(Optional.of(completed));

        assertThatThrownBy(() -> service.update(ACTOR_ID, completed.getId(),
            new UpdateAttentionRequest(null, "cambio", 0L)))
            .isInstanceOf(InvalidClinicalStateException.class);
        verify(attentions, never()).save(any());
    }

    @Test
    void get_rejectsAttentionFromOtherInstitution() {
        UUID id = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(attentions.findByIdAndInstitutionId(id, INSTITUTION_ID))
            .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(ACTOR_ID, id))
            .isInstanceOf(AttentionNotFoundException.class);
    }

    @Test
    void registerDose_rejectedWhenAttentionCancelled() {
        AttentionEntity cancelled = attention(AttentionEntity.Status.CANCELLED);
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(attentions.findByIdAndInstitutionId(cancelled.getId(), INSTITUTION_ID))
            .thenReturn(Optional.of(cancelled));

        assertThatThrownBy(() -> service.registerDose(ACTOR_ID, OPERATION_ID,
            cancelled.getId(), new RegisterDoseRequest(UUID.randomUUID(),
                UUID.randomUUID(), null, null, null, null, null, null, null, null)))
            .isInstanceOf(InvalidClinicalStateException.class);
        verify(doses, never()).save(any());
    }

    @Test
    void registerDose_snapshotsCatalogValuesAndPersists() {
        AttentionEntity draft = attention(AttentionEntity.Status.DRAFT);
        UUID vaccineId = UUID.randomUUID();
        UUID doseOptionId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(attentions.findByIdAndInstitutionId(draft.getId(), INSTITUTION_ID))
            .thenReturn(Optional.of(draft));

        VaccineEntity vaccine = new VaccineEntity(vaccineId, "Influenza", "INF", "PAI",
            (short) 1, null, null, ACTOR_ID, Instant.now());
        when(vaccines.findById(vaccineId)).thenReturn(Optional.of(vaccine));
        InstitutionVaccineEntity relation = mock(InstitutionVaccineEntity.class);
        when(relation.isEnabled()).thenReturn(true);
        when(institutionVaccines.findByInstitutionIdAndVaccineId(INSTITUTION_ID, vaccineId))
            .thenReturn(Optional.of(relation));
        VaccineOptionEntity doseOption = new VaccineOptionEntity(doseOptionId, vaccineId,
            "dose", "1", "Primera dosis", 0, true, ACTOR_ID, Instant.now());
        when(vaccineOptions.findByIdAndVaccineId(doseOptionId, vaccineId))
            .thenReturn(Optional.of(doseOption));
        when(doses.save(any(AppliedDoseEntity.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));

        var response = service.registerDose(ACTOR_ID, OPERATION_ID, draft.getId(),
            new RegisterDoseRequest(vaccineId, doseOptionId, null, null, null, null,
                null, null, null, null));

        assertThat(response.vaccineNameSnapshot()).isEqualTo("Influenza");
        assertThat(response.vaccineCodeSnapshot()).isEqualTo("INF");
        assertThat(response.doseLabelSnapshot()).isEqualTo("Primera dosis");
        assertThat(response.catalogVersion()).isEqualTo(vaccine.getVersion());
        assertThat(response.status()).isEqualTo("REGISTERED");

        ArgumentCaptor<AppliedDoseEntity> captor =
            ArgumentCaptor.forClass(AppliedDoseEntity.class);
        verify(doses).save(captor.capture());
        assertThat(captor.getValue().getApplicationDate()).isNotNull();
        verify(audit).record(eq(ACTOR_ID), eq(INSTITUTION_ID),
            eq(AuditAction.DOSE_REGISTERED), eq("APPLIED_DOSE"), any(), any(), any());
    }

    @Test
    void cancelDose_rejectsAlreadyCancelledDose() {
        AttentionEntity draft = attention(AttentionEntity.Status.DRAFT);
        AppliedDoseEntity applied = dose(draft.getId());
        applied.cancel("dosis aplicada por error", ACTOR_ID, Instant.now());
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(attentions.findByIdAndInstitutionId(draft.getId(), INSTITUTION_ID))
            .thenReturn(Optional.of(draft));
        when(doses.findByIdAndAttentionId(applied.getId(), draft.getId()))
            .thenReturn(Optional.of(applied));

        assertThatThrownBy(() -> service.cancelDose(ACTOR_ID, draft.getId(),
            applied.getId(), new CancelDoseRequest("otra vez cancelada")))
            .isInstanceOf(InvalidClinicalStateException.class);
        verify(doses, never()).save(any());
    }

    @Test
    void listByPatient_isScopedToInstitution() {
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        AttentionEntity first = attention(AttentionEntity.Status.COMPLETED);
        when(attentions.findByInstitutionIdAndPatientIdOrderByAttentionDateDesc(
            INSTITUTION_ID, PATIENT_ID)).thenReturn(List.of(first));
        when(doses.findByAttentionIdOrderByCreatedAtAsc(first.getId()))
            .thenReturn(List.of());

        List<AttentionResponse> result = service.listByPatient(ACTOR_ID, PATIENT_ID);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).id()).isEqualTo(first.getId());
    }

    @Test
    void complete_transitionsDraftToCompleted() {
        AttentionEntity draft = attention(AttentionEntity.Status.DRAFT);
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(attentions.findByIdAndInstitutionId(draft.getId(), INSTITUTION_ID))
            .thenReturn(Optional.of(draft));
        when(attentions.save(any(AttentionEntity.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));
        when(doses.findByAttentionIdOrderByCreatedAtAsc(draft.getId()))
            .thenReturn(List.of());

        AttentionResponse response = service.complete(ACTOR_ID, draft.getId());

        assertThat(response.status()).isEqualTo("COMPLETED");
        verify(audit).record(eq(ACTOR_ID), eq(INSTITUTION_ID),
            eq(AuditAction.ATTENTION_COMPLETED), eq("ATTENTION"), any(), any(), any());
    }
}
