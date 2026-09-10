package com.pai.api.attentions.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pai.api.attentions.dto.AppliedDoseResponse;
import com.pai.api.attentions.dto.AttentionResponse;
import com.pai.api.attentions.dto.CancelAttentionRequest;
import com.pai.api.attentions.dto.CancelDoseRequest;
import com.pai.api.attentions.dto.CreateAttentionRequest;
import com.pai.api.attentions.dto.RegisterDoseRequest;
import com.pai.api.attentions.dto.UpdateAttentionRequest;
import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.exception.AttentionNotFoundException;
import com.pai.api.attentions.exception.DoseNotFoundException;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.audit.AuditAction;
import com.pai.api.audit.service.AuditService;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.synchronization.service.ProcessedOperationsService;

/**
 * Gestion clinica de atenciones y dosis aplicadas.
 *
 * <p>Reglas de dominio (invariantes):
 * <ul>
 *   <li>{@code Attention} es mutable solo en {@code DRAFT}/{@code IN_PROGRESS};
 *       {@code COMPLETED} es inmutable y solo se anula con motivo.</li>
 *   <li>Una atencion anulada no recibe nuevas dosis.</li>
 *   <li>{@code AppliedDose} es append-only: se registra o se cancela con
 *       motivo; nunca se edita ni se borra.</li>
 *   <li>La dosis guarda snapshot del catalogo vigente al momento del registro.
 *   </li>
 * </ul>
 * El alcance institucional se deriva del actor (ADR-007); la institucion nunca
 * se confia al cliente.
 */
@Service
public class AttentionService {

    private static final String RESOURCE_TYPE_ATTENTION = "ATTENTION";
    private static final String RESOURCE_TYPE_DOSE = "APPLIED_DOSE";
    private static final String FIELD_DOSE = "dose";
    private static final String FIELD_PNEUMOCOCCAL = "pneumococcalType";

    private final AttentionRepository attentions;
    private final AppliedDoseRepository doses;
    private final PatientRepository patients;
    private final VaccineRepository vaccines;
    private final VaccineOptionRepository vaccineOptions;
    private final InstitutionVaccineRepository institutionVaccines;
    private final InstitutionVaccineOptionRepository institutionOptions;
    private final IdentityService identity;
    private final DataScope dataScope;
    private final AuditService audit;
    private final ProcessedOperationsService processedOperations;

    public AttentionService(
            AttentionRepository attentions,
            AppliedDoseRepository doses,
            PatientRepository patients,
            VaccineRepository vaccines,
            VaccineOptionRepository vaccineOptions,
            InstitutionVaccineRepository institutionVaccines,
            InstitutionVaccineOptionRepository institutionOptions,
            IdentityService identity,
            DataScope dataScope,
            AuditService audit,
            ProcessedOperationsService processedOperations) {
        this.attentions = attentions;
        this.doses = doses;
        this.patients = patients;
        this.vaccines = vaccines;
        this.vaccineOptions = vaccineOptions;
        this.institutionVaccines = institutionVaccines;
        this.institutionOptions = institutionOptions;
        this.identity = identity;
        this.dataScope = dataScope;
        this.audit = audit;
        this.processedOperations = processedOperations;
    }

    @Transactional
    public AttentionResponse create(UUID actorId, String operationId,
            CreateAttentionRequest request) {
        var previous = processedOperations.find(operationId, AttentionResponse.class);
        if (previous.isPresent()) {
            return previous.get();
        }

        AuthorizedUser actor = identity.resolve(actorId);
        UUID institutionId = institution(actor);
        requirePatientScoped(institutionId, request.patientId());

        Instant now = Instant.now();
        Instant attentionDate = request.attentionDate() != null
            ? request.attentionDate()
            : now;
        long consecutive = attentions.maxConsecutive(institutionId) + 1;

        AttentionEntity attention = attentions.save(new AttentionEntity(
            UUID.randomUUID(), request.patientId(), actor.getId(), institutionId,
            attentionDate, consecutive, parseOperationId(operationId), now));
        attention.updateDetails(attentionDate, blankToNull(request.observations()), now);
        attentions.save(attention);

        AttentionResponse response = toResponse(attention);
        audit.record(actor.getId(), institutionId, AuditAction.ATTENTION_CREATED,
            RESOURCE_TYPE_ATTENTION, attention.getId(), parseOperationId(operationId),
            response);
        processedOperations.record(operationId, "CREATE_ATTENTION", attention.getId(),
            response);
        return response;
    }

    @Transactional(readOnly = true)
    public AttentionResponse get(UUID actorId, UUID attentionId) {
        AuthorizedUser actor = identity.resolve(actorId);
        return toResponse(requireScoped(actor, attentionId));
    }

    @Transactional(readOnly = true)
    public List<AttentionResponse> listByPatient(UUID actorId, UUID patientId) {
        AuthorizedUser actor = identity.resolve(actorId);
        UUID institutionId = institution(actor);
        return attentions
            .findByInstitutionIdAndPatientIdOrderByAttentionDateDesc(institutionId, patientId)
            .stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public AttentionResponse update(UUID actorId, UUID attentionId,
            UpdateAttentionRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        requireEditable(attention);

        if (attention.getVersion() != request.version()) {
            throw new OptimisticCatalogException(
                "La atencion fue modificada por otro usuario.");
        }

        Instant now = Instant.now();
        Instant attentionDate = request.attentionDate() != null
            ? request.attentionDate()
            : attention.getAttentionDate();
        attention.updateDetails(attentionDate, blankToNull(request.observations()), now);
        attentions.save(attention);

        AttentionResponse response = toResponse(attention);
        audit.record(actor.getId(), attention.getInstitutionId(),
            AuditAction.ATTENTION_UPDATED, RESOURCE_TYPE_ATTENTION, attentionId, null,
            response);
        return response;
    }

    @Transactional
    public AttentionResponse complete(UUID actorId, UUID attentionId) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        requireEditable(attention);

        Instant now = Instant.now();
        attention.complete(now);
        attentions.save(attention);

        AttentionResponse response = toResponse(attention);
        audit.record(actor.getId(), attention.getInstitutionId(),
            AuditAction.ATTENTION_COMPLETED, RESOURCE_TYPE_ATTENTION, attentionId, null,
            response);
        return response;
    }

    @Transactional
    public AttentionResponse cancel(UUID actorId, UUID attentionId,
            CancelAttentionRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        if (attention.getStatus() == AttentionEntity.Status.CANCELLED) {
            throw new InvalidClinicalStateException("La atencion ya esta anulada.");
        }

        Instant now = Instant.now();
        attention.cancel(now);
        attentions.save(attention);

        AttentionResponse response = toResponse(attention);
        audit.record(actor.getId(), attention.getInstitutionId(),
            AuditAction.ATTENTION_CANCELLED, RESOURCE_TYPE_ATTENTION, attentionId, null,
            new Cancellation(response, request.reason()));
        return response;
    }

    @Transactional
    public AppliedDoseResponse registerDose(UUID actorId, String operationId,
            UUID attentionId, RegisterDoseRequest request) {
        var previous = processedOperations.find(operationId, AppliedDoseResponse.class);
        if (previous.isPresent()) {
            return previous.get();
        }

        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        if (!attention.acceptsDoses()) {
            throw new InvalidClinicalStateException(
                "No se pueden registrar dosis en una atencion completada o anulada.");
        }
        UUID institutionId = attention.getInstitutionId();

        VaccineEntity vaccine = requireEnabledVaccine(institutionId, request.vaccineId());
        VaccineOptionEntity doseOption = requireOption(
            request.doseOptionId(), vaccine.getId(), FIELD_DOSE,
            "La dosis seleccionada no es valida.");
        VaccineOptionEntity pneumo = request.pneumococcalTypeOptionId() == null
            ? null
            : requireOption(request.pneumococcalTypeOptionId(), vaccine.getId(),
                FIELD_PNEUMOCOCCAL, "El tipo de neumococo seleccionado no es valido.");

        ResolvedOption laboratory = resolveInstitutionOption(
            institutionId, vaccine.getId(), request.selectedLaboratoryId(), "laboratory");
        ResolvedOption syringe = resolveInstitutionOption(
            institutionId, vaccine.getId(), request.selectedSyringeId(), "syringe");
        ResolvedOption dropper = resolveInstitutionOption(
            institutionId, vaccine.getId(), request.selectedDropperId(), "dropper");
        ResolvedOption observation = resolveInstitutionOption(
            institutionId, vaccine.getId(), request.selectedObservationId(), "observation");

        Instant now = Instant.now();
        Instant applicationDate = request.applicationDate() != null
            ? request.applicationDate()
            : now;

        AppliedDoseEntity dose = doses.save(new AppliedDoseEntity(
            UUID.randomUUID(), attentionId, vaccine.getId(), request.lotId(),
            blankToNull(request.lotNumber()), applicationDate,
            doseOption.getId(), pneumo != null ? pneumo.getId() : null,
            vaccine.getName(), vaccine.getCode(), doseOption.getDisplayName(),
            doseOption.getValue(), pneumo != null ? pneumo.getDisplayName() : null,
            vaccine.getVersion(),
            id(laboratory), label(laboratory),
            id(syringe), label(syringe),
            id(dropper), label(dropper),
            id(observation), label(observation), now));

        AppliedDoseResponse response = toDoseResponse(dose);
        audit.record(actor.getId(), institutionId, AuditAction.DOSE_REGISTERED,
            RESOURCE_TYPE_DOSE, dose.getId(), parseOperationId(operationId), response);
        processedOperations.record(operationId, "REGISTER_APPLIED_DOSE", dose.getId(),
            response);
        return response;
    }

    @Transactional
    public AppliedDoseResponse cancelDose(UUID actorId, UUID attentionId, UUID doseId,
            CancelDoseRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);

        AppliedDoseEntity dose = doses.findByIdAndAttentionId(doseId, attentionId)
            .orElseThrow(() -> new DoseNotFoundException(
                "La dosis no existe en la atencion indicada."));
        if (dose.getStatus() == AppliedDoseEntity.Status.CANCELLED) {
            throw new InvalidClinicalStateException("La dosis ya esta anulada.");
        }

        Instant now = Instant.now();
        dose.cancel(request.reason(), actor.getId(), now);
        doses.save(dose);

        AppliedDoseResponse response = toDoseResponse(dose);
        audit.record(actor.getId(), attention.getInstitutionId(),
            AuditAction.DOSE_CANCELLED, RESOURCE_TYPE_DOSE, doseId, null,
            new Cancellation(response, request.reason()));
        return response;
    }

    // ---------- helpers ----------

    private record Cancellation(Object resource, String reason) {
    }

    private record ResolvedOption(UUID id, String displayName) {
    }

    private UUID institution(AuthorizedUser actor) {
        return dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    }

    private void requirePatientScoped(UUID institutionId, UUID patientId) {
        if (patients.findByIdAndInstitutionId(patientId, institutionId).isEmpty()) {
            throw new PatientNotFoundException(
                "El paciente no existe o no pertenece a tu institucion.");
        }
    }

    private AttentionEntity requireScoped(AuthorizedUser actor, UUID attentionId) {
        UUID institutionId = institution(actor);
        return attentions.findByIdAndInstitutionId(attentionId, institutionId)
            .orElseThrow(() -> new AttentionNotFoundException(
                "La atencion no existe o no pertenece a tu institucion."));
    }

    private void requireEditable(AttentionEntity attention) {
        if (!attention.isEditable()) {
            throw new InvalidClinicalStateException(
                "La atencion no se puede modificar en su estado actual ("
                    + attention.getStatus() + ").");
        }
    }

    private VaccineEntity requireEnabledVaccine(UUID institutionId, UUID vaccineId) {
        VaccineEntity vaccine = vaccines.findById(vaccineId)
            .orElseThrow(() -> new IllegalArgumentException("La vacuna no existe."));
        if (!vaccine.isActive()) {
            throw new InvalidClinicalStateException("La vacuna esta inactiva.");
        }
        boolean enabled = institutionVaccines
            .findByInstitutionIdAndVaccineId(institutionId, vaccineId)
            .filter(InstitutionVaccineEntity::isEnabled)
            .isPresent();
        if (!enabled) {
            throw new InvalidClinicalStateException(
                "La vacuna no esta habilitada en tu institucion.");
        }
        return vaccine;
    }

    private VaccineOptionEntity requireOption(UUID optionId, UUID vaccineId,
            String expectedType, String message) {
        VaccineOptionEntity option = vaccineOptions.findByIdAndVaccineId(optionId, vaccineId)
            .orElseThrow(() -> new IllegalArgumentException(message));
        if (!option.isActive() || !expectedType.equals(option.getFieldType())) {
            throw new IllegalArgumentException(message);
        }
        return option;
    }

    private ResolvedOption resolveInstitutionOption(UUID institutionId, UUID vaccineId,
            UUID optionId, String expectedType) {
        if (optionId == null) {
            return null;
        }
        InstitutionVaccineOptionEntity option = institutionOptions
            .findByIdAndInstitutionIdAndVaccineId(optionId, institutionId, vaccineId)
            .orElseThrow(() -> new IllegalArgumentException(
                "La opcion operativa seleccionada no es valida."));
        if (!option.isActive() || !expectedType.equals(option.getFieldType())) {
            throw new IllegalArgumentException(
                "La opcion operativa seleccionada no es valida.");
        }
        return new ResolvedOption(option.getId(), option.getDisplayName());
    }

    private UUID id(ResolvedOption option) {
        return option == null ? null : option.id();
    }

    private String label(ResolvedOption option) {
        return option == null ? null : option.displayName();
    }

    private String blankToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private UUID parseOperationId(String operationId) {
        if (operationId == null || operationId.isBlank()) {
            return null;
        }
        try {
            return UUID.fromString(operationId.trim());
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private AttentionResponse toResponse(AttentionEntity attention) {
        List<AppliedDoseResponse> doseResponses = new ArrayList<>();
        for (AppliedDoseEntity dose : doses
                .findByAttentionIdOrderByCreatedAtAsc(attention.getId())) {
            doseResponses.add(toDoseResponse(dose));
        }
        return new AttentionResponse(
            attention.getId(), attention.getPatientId(), attention.getProfessionalId(),
            attention.getInstitutionId(), attention.getAttentionDate(),
            attention.getConsecutive(), attention.getStatus().name(),
            attention.getObservations(), attention.getVersion(),
            attention.getCreatedAt(), attention.getUpdatedAt(), doseResponses);
    }

    private AppliedDoseResponse toDoseResponse(AppliedDoseEntity dose) {
        return new AppliedDoseResponse(
            dose.getId(), dose.getAttentionId(), dose.getVaccineId(),
            dose.getVaccineNameSnapshot(), dose.getVaccineCodeSnapshot(),
            dose.getDoseOptionId(), dose.getDoseLabelSnapshot(), dose.getDoseValueSnapshot(),
            dose.getPneumococcalTypeOptionId(), dose.getPneumococcalTypeSnapshot(),
            dose.getLotId(), dose.getLotNumber(), dose.getApplicationDate(),
            dose.getCatalogVersion(), dose.getSelectedLaboratorySnapshot(),
            dose.getSelectedSyringeSnapshot(), dose.getSelectedDropperSnapshot(),
            dose.getSelectedObservationSnapshot(), dose.getStatus().name(),
            dose.getCancelledReason(), dose.getCancelledAt(), dose.getCreatedAt());
    }
}
