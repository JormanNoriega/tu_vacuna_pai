package com.pai.api.attentions.service;

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
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.shared.application.IdempotencyCoordinator;
import com.pai.api.shared.util.Strings;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
 *
 * <p>Sosten del refactor SOLID:
 * <ul>
 *   <li><b>DIP</b>: el catalogo se consulta via {@link VaccineCatalogPolicy};
 *       no inyecta repositorios del modulo {@code catalog}.</li>
 *   <li><b>OCP</b>: la ceremonia idempotencia + auditoria la ejecuta
 *       {@link IdempotencyCoordinator}; el servicio solo aporta el cuerpo.</li>
 *   <li><b>SRP</b>: el mapeo entidad {@literal ->} DTO esta en
 *       {@link AttentionMapper}.</li>
 * </ul>
 */
@Service
public class AttentionService {

    private static final String RESOURCE_TYPE_ATTENTION = "ATTENTION";
    private static final String RESOURCE_TYPE_DOSE = "APPLIED_DOSE";

    private final AttentionRepository attentions;
    private final AppliedDoseRepository doses;
    private final PatientRepository patients;
    private final VaccineCatalogPolicy catalogPolicy;
    private final IdentityService identity;
    private final DataScope dataScope;
    private final AuditService audit;
    private final IdempotencyCoordinator coordinator;
    private final AttentionMapper mapper;

    public AttentionService(
            AttentionRepository attentions,
            AppliedDoseRepository doses,
            PatientRepository patients,
            VaccineCatalogPolicy catalogPolicy,
            IdentityService identity,
            DataScope dataScope,
            AuditService audit,
            IdempotencyCoordinator coordinator,
            AttentionMapper mapper) {
        this.attentions = attentions;
        this.doses = doses;
        this.patients = patients;
        this.catalogPolicy = catalogPolicy;
        this.identity = identity;
        this.dataScope = dataScope;
        this.audit = audit;
        this.coordinator = coordinator;
        this.mapper = mapper;
    }

    @Transactional
    public AttentionResponse create(UUID actorId, String operationId, CreateAttentionRequest request) {
        return coordinator.execute(
                operationId,
                "CREATE_ATTENTION",
                AttentionResponse.class,
                () -> auditContext(actorId, AuditAction.ATTENTION_CREATED, RESOURCE_TYPE_ATTENTION),
                () -> {
                    AuthorizedUser actor = identity.resolve(actorId);
                    UUID institutionId = institution(actor);
                    requirePatientScoped(institutionId, request.patientId());
                    Instant now = Instant.now();
                    Instant attentionDate = request.attentionDate() != null ? request.attentionDate() : now;
                    long consecutive = attentions.maxConsecutive(institutionId) + 1;

                    AttentionEntity attention = attentions.save(new AttentionEntity(
                            UUID.randomUUID(),
                            request.patientId(),
                            actor.getId(),
                            institutionId,
                            attentionDate,
                            consecutive,
                            coordinator.parseOperationId(operationId),
                            now));
                    attention.updateDetails(attentionDate, Strings.blankToNull(request.observations()), now);
                    attentions.save(attention);
                    return new IdempotencyCoordinator.WriteResult<>(attention.getId(), response(attention));
                });
    }

    @Transactional(readOnly = true)
    public AttentionResponse get(UUID actorId, UUID attentionId) {
        AuthorizedUser actor = identity.resolve(actorId);
        return response(requireScoped(actor, attentionId));
    }

    @Transactional(readOnly = true)
    public List<AttentionResponse> listByPatient(UUID actorId, UUID patientId) {
        AuthorizedUser actor = identity.resolve(actorId);
        UUID institutionId = institution(actor);
        return attentions.findByInstitutionIdAndPatientIdOrderByAttentionDateDesc(institutionId, patientId).stream()
                .map(this::response)
                .toList();
    }

    @Transactional
    public AttentionResponse update(UUID actorId, UUID attentionId, UpdateAttentionRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        requireEditable(attention);

        if (attention.getVersion() != request.version()) {
            throw new OptimisticCatalogException("La atencion fue modificada por otro usuario.");
        }

        return coordinator.executeAudited(
                actor.getId(),
                attention.getInstitutionId(),
                AuditAction.ATTENTION_UPDATED,
                RESOURCE_TYPE_ATTENTION,
                attentionId,
                () -> {
                    Instant now = Instant.now();
                    Instant attentionDate =
                            request.attentionDate() != null ? request.attentionDate() : attention.getAttentionDate();
                    attention.updateDetails(attentionDate, Strings.blankToNull(request.observations()), now);
                    attentions.save(attention);
                    return response(attention);
                });
    }

    @Transactional
    public AttentionResponse complete(UUID actorId, UUID attentionId) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        requireEditable(attention);

        return coordinator.executeAudited(
                actor.getId(),
                attention.getInstitutionId(),
                AuditAction.ATTENTION_COMPLETED,
                RESOURCE_TYPE_ATTENTION,
                attentionId,
                () -> {
                    attention.complete(Instant.now());
                    attentions.save(attention);
                    return response(attention);
                });
    }

    @Transactional
    public AttentionResponse cancel(UUID actorId, UUID attentionId, CancelAttentionRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        if (attention.getStatus() == AttentionEntity.Status.CANCELLED) {
            throw new InvalidClinicalStateException("La atencion ya esta anulada.");
        }

        attention.cancel(Instant.now());
        attentions.save(attention);

        AttentionResponse response = response(attention);
        audit.record(
                actor.getId(),
                attention.getInstitutionId(),
                AuditAction.ATTENTION_CANCELLED,
                RESOURCE_TYPE_ATTENTION,
                attentionId,
                null,
                new Cancellation(response, request.reason()));
        return response;
    }

    @Transactional
    public AppliedDoseResponse registerDose(
            UUID actorId, String operationId, UUID attentionId, RegisterDoseRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);
        if (!attention.acceptsDoses()) {
            throw new InvalidClinicalStateException(
                    "No se pueden registrar dosis en una atencion completada o anulada.");
        }
        UUID institutionId = attention.getInstitutionId();

        return coordinator.execute(
                operationId,
                "REGISTER_APPLIED_DOSE",
                AppliedDoseResponse.class,
                () -> auditContext(actor.getId(), AuditAction.DOSE_REGISTERED, RESOURCE_TYPE_DOSE),
                () -> {
                    VaccineCatalogPolicy.DoseSelection selection = catalogPolicy.resolve(
                            new VaccineCatalogPolicy.ResolutionRequest(
                                    institutionId,
                                    request.vaccineId(),
                                    request.doseOptionId(),
                                    request.pneumococcalTypeOptionId(),
                                    request.selectedLaboratoryId(),
                                    request.selectedSyringeId(),
                                    request.selectedDropperId(),
                                    request.selectedObservationId()));

                    Instant now = Instant.now();
                    Instant applicationDate = request.applicationDate() != null ? request.applicationDate() : now;

                    AppliedDoseEntity dose = doses.save(new AppliedDoseEntity(
                            UUID.randomUUID(),
                            attentionId,
                            selection.vaccineId(),
                            request.lotId(),
                            Strings.blankToNull(request.lotNumber()),
                            applicationDate,
                            selection.doseOptionId(),
                            selection.pneumococcalTypeOptionId(),
                            selection.vaccineName(),
                            selection.vaccineCode(),
                            selection.doseLabel(),
                            selection.doseValue(),
                            selection.pneumococcalTypeSnapshot(),
                            selection.catalogVersion(),
                            selection.laboratoryId(),
                            selection.laboratorySnapshot(),
                            selection.syringeId(),
                            selection.syringeSnapshot(),
                            selection.dropperId(),
                            selection.dropperSnapshot(),
                            selection.observationId(),
                            selection.observationSnapshot(),
                            now));
                    return new IdempotencyCoordinator.WriteResult<>(dose.getId(), mapper.toDoseResponse(dose));
                });
    }

    @Transactional
    public AppliedDoseResponse cancelDose(UUID actorId, UUID attentionId, UUID doseId, CancelDoseRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        AttentionEntity attention = requireScoped(actor, attentionId);

        AppliedDoseEntity dose = doses.findByIdAndAttentionId(doseId, attentionId)
                .orElseThrow(() -> new DoseNotFoundException("La dosis no existe en la atencion indicada."));
        if (dose.getStatus() == AppliedDoseEntity.Status.CANCELLED) {
            throw new InvalidClinicalStateException("La dosis ya esta anulada.");
        }

        dose.cancel(request.reason(), actor.getId(), Instant.now());
        doses.save(dose);

        AppliedDoseResponse response = mapper.toDoseResponse(dose);
        audit.record(
                actor.getId(),
                attention.getInstitutionId(),
                AuditAction.DOSE_CANCELLED,
                RESOURCE_TYPE_DOSE,
                doseId,
                null,
                new Cancellation(response, request.reason()));
        return response;
    }

    // ---------- helpers ----------

    private record Cancellation(Object resource, String reason) {}

    private IdempotencyCoordinator.AuditContext auditContext(
            UUID actorId, AuditAction action, String resourceType) {
        AuthorizedUser actor = identity.resolve(actorId);
        return new IdempotencyCoordinator.AuditContext(
                actor.getId(), institution(actor), action, resourceType);
    }

    private UUID institution(AuthorizedUser actor) {
        return dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    }

    private void requirePatientScoped(UUID institutionId, UUID patientId) {
        if (patients.findByIdAndInstitutionId(patientId, institutionId).isEmpty()) {
            throw new PatientNotFoundException("El paciente no existe o no pertenece a tu institucion.");
        }
    }

    private AttentionEntity requireScoped(AuthorizedUser actor, UUID attentionId) {
        UUID institutionId = institution(actor);
        return attentions
                .findByIdAndInstitutionId(attentionId, institutionId)
                .orElseThrow(
                        () -> new AttentionNotFoundException("La atencion no existe o no pertenece a tu institucion."));
    }

    private void requireEditable(AttentionEntity attention) {
        if (!attention.isEditable()) {
            throw new InvalidClinicalStateException(
                    "La atencion no se puede modificar en su estado actual (" + attention.getStatus() + ").");
        }
    }

    private AttentionResponse response(AttentionEntity attention) {
        List<AppliedDoseResponse> doseResponses = doses.findByAttentionIdOrderByCreatedAtAsc(attention.getId()).stream()
                .map(mapper::toDoseResponse)
                .toList();
        return mapper.toResponse(attention, doseResponses);
    }
}