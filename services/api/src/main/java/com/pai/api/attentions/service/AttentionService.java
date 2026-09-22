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
import com.pai.api.audit.AuditResourceType;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.shared.application.IdempotencyCoordinator;
import com.pai.api.shared.util.Strings;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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
 * se confia al cliente. En el camino offline-first cada escritura admite un
 * {@code operationId} y respeta el {@code aggregate_id} del cliente.
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

  private final AttentionRepository attentions;
  private final AppliedDoseRepository doses;
  private final PatientScopePolicy patientScope;
  private final VaccineCatalogPolicy catalogPolicy;
  private final IdentityService identity;
  private final DataScope dataScope;
  private final IdempotencyCoordinator coordinator;
  private final AttentionMapper mapper;
  private final DoseCommandPayloadFactory dosePayloadFactory;

  public AttentionService(
      AttentionRepository attentions,
      AppliedDoseRepository doses,
      PatientScopePolicy patientScope,
      VaccineCatalogPolicy catalogPolicy,
      IdentityService identity,
      DataScope dataScope,
      IdempotencyCoordinator coordinator,
      AttentionMapper mapper,
      DoseCommandPayloadFactory dosePayloadFactory) {
    this.attentions = attentions;
    this.doses = doses;
    this.patientScope = patientScope;
    this.catalogPolicy = catalogPolicy;
    this.identity = identity;
    this.dataScope = dataScope;
    this.coordinator = coordinator;
    this.mapper = mapper;
    this.dosePayloadFactory = dosePayloadFactory;
  }

  @Transactional
  public AttentionResponse create(
      UUID actorId, String operationId, CreateAttentionRequest request) {
    return create(actorId, operationId, null, request);
  }

  /**
   * Crea una atencion. Para el camino offline-first, {@code attentionId} es el
   * {@code aggregate_id} del cliente y el servidor lo respeta como PK; en el
   * camino REST directo llega {@code null} y el servidor genera el UUID.
   */
  @Transactional
  public AttentionResponse create(
      UUID actorId, String operationId, UUID attentionId, CreateAttentionRequest request) {
    return coordinator.execute(
        operationId,
        "CREATE_ATTENTION",
        AttentionResponse.class,
        () -> auditContext(actorId, AuditAction.ATTENTION_CREATED, AuditResourceType.ATTENTION),
        () -> request,
        () -> {
          AuthorizedUser actor = identity.resolve(actorId);
          UUID institutionId = institution(actor);
          requirePatientScoped(institutionId, request.patientId());
          Instant now = Instant.now();
          Instant attentionDate = request.attentionDate() != null ? request.attentionDate() : now;
          long consecutive = attentions.maxConsecutive(institutionId) + 1;

          AttentionEntity attention = attentions.save(new AttentionEntity(
              attentionId != null ? attentionId : UUID.randomUUID(),
              request.patientId(),
              actor.getId(),
              institutionId,
              attentionDate,
              consecutive,
              coordinator.parseOperationId(operationId),
              now));
          attention.updateDetails(attentionDate, Strings.blankToNull(request.observations()), now);
          attention.applyRegistrationDetails(
              request.completeScheme(),
              request.paiwebRegistered(),
              Strings.blankToNull(request.paiwebNotRegisteredReason()),
              now);
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
    List<AttentionEntity> found =
        attentions.findByInstitutionIdAndPatientIdOrderByAttentionDateDesc(
            institutionId, patientId);
    Map<UUID, List<AppliedDoseResponse>> dosesByAttention = doseResponsesByAttention(found);
    return found.stream()
        .map(attention -> mapper.toResponse(
            attention, dosesByAttention.getOrDefault(attention.getId(), List.of())))
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
        AuditResourceType.ATTENTION,
        attentionId,
        () -> {
          Instant now = Instant.now();
          Instant attentionDate = request.attentionDate() != null
              ? request.attentionDate()
              : attention.getAttentionDate();
          attention.updateDetails(attentionDate, Strings.blankToNull(request.observations()), now);
          attention.applyRegistrationDetails(
              request.completeScheme(),
              request.paiwebRegistered(),
              Strings.blankToNull(request.paiwebNotRegisteredReason()),
              now);
          attentions.save(attention);
          return response(attention);
        });
  }

  @Transactional
  public AttentionResponse complete(UUID actorId, UUID attentionId) {
    return complete(actorId, null, attentionId);
  }

  /**
   * Completa una atencion. Idempotente por {@code operationId} para el pull
   * offline: el {@link IdempotencyCoordinator} repite la respuesta guardada
   * sin ejecutar la transicion de estado.
   */
  @Transactional
  public AttentionResponse complete(UUID actorId, String operationId, UUID attentionId) {
    return coordinator.execute(
        operationId,
        "COMPLETE_ATTENTION",
        AttentionResponse.class,
        () -> auditContext(actorId, AuditAction.ATTENTION_COMPLETED, AuditResourceType.ATTENTION),
        Map::of,
        () -> {
          AuthorizedUser actor = identity.resolve(actorId);
          AttentionEntity attention = requireScoped(actor, attentionId);
          requireEditable(attention);
          attention.complete(Instant.now());
          attentions.save(attention);
          return new IdempotencyCoordinator.WriteResult<>(attention.getId(), response(attention));
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

    return coordinator.executeAudited(
        actor.getId(),
        attention.getInstitutionId(),
        AuditAction.ATTENTION_CANCELLED,
        AuditResourceType.ATTENTION,
        attentionId,
        response -> new Cancellation(response, request.reason()),
        () -> response(attention));
  }

  @Transactional
  public AppliedDoseResponse registerDose(
      UUID actorId, String operationId, UUID attentionId, RegisterDoseRequest request) {
    return registerDose(actorId, operationId, attentionId, null, request);
  }

  /**
   * Registra una dosis aplicada. Para el camino offline-first, {@code doseId}
   * es el {@code aggregate_id} del cliente y el servidor lo respeta como PK; en
   * el camino REST directo llega {@code null} y el servidor genera el UUID.
   */
  @Transactional
  public AppliedDoseResponse registerDose(
      UUID actorId,
      String operationId,
      UUID attentionId,
      UUID doseId,
      RegisterDoseRequest request) {
    return coordinator.execute(
        operationId,
        "REGISTER_APPLIED_DOSE",
        AppliedDoseResponse.class,
        () -> auditContext(actorId, AuditAction.DOSE_REGISTERED, AuditResourceType.APPLIED_DOSE),
        () -> dosePayloadFactory.forDose(attentionId, request),
        () -> {
          AuthorizedUser actor = identity.resolve(actorId);
          AttentionEntity attention = requireScoped(actor, attentionId);
          if (!attention.acceptsDoses()) {
            throw new InvalidClinicalStateException(
                "No se pueden registrar dosis en una atencion completada o anulada.");
          }
          UUID institutionId = attention.getInstitutionId();

          VaccineCatalogPolicy.DoseSelection selection =
              catalogPolicy.resolve(new VaccineCatalogPolicy.ResolutionRequest(
                  institutionId,
                  request.vaccineId(),
                  request.doseOptionId(),
                  request.pneumococcalTypeOptionId(),
                  request.selectedLaboratoryId(),
                  request.selectedSyringeId(),
                  request.selectedDropperId(),
                  request.selectedObservationId()));

          Instant now = Instant.now();
          Instant applicationDate =
              request.applicationDate() != null ? request.applicationDate() : now;

          AppliedDoseEntity dose = new AppliedDoseEntity(
              doseId != null ? doseId : UUID.randomUUID(),
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
              now);
          dose.applyOperationalFields(
              Strings.blankToNull(request.syringeLot()),
              Strings.blankToNull(request.diluent()),
              request.vialCount(),
              Strings.blankToNull(request.customObservation()));
          doses.save(dose);
          return new IdempotencyCoordinator.WriteResult<>(
              dose.getId(), mapper.toDoseResponse(dose));
        });
  }

  @Transactional
  public AppliedDoseResponse cancelDose(
      UUID actorId, UUID attentionId, UUID doseId, CancelDoseRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    AttentionEntity attention = requireScoped(actor, attentionId);

    AppliedDoseEntity dose = doses
        .findByIdAndAttentionId(doseId, attentionId)
        .orElseThrow(
            () -> new DoseNotFoundException("La dosis no existe en la atencion indicada."));
    if (dose.getStatus() == AppliedDoseEntity.Status.CANCELLED) {
      throw new InvalidClinicalStateException("La dosis ya esta anulada.");
    }

    dose.cancel(request.reason(), actor.getId(), Instant.now());
    doses.save(dose);

    return coordinator.executeAudited(
        actor.getId(),
        attention.getInstitutionId(),
        AuditAction.DOSE_CANCELLED,
        AuditResourceType.APPLIED_DOSE,
        doseId,
        response -> new Cancellation(response, request.reason()),
        () -> mapper.toDoseResponse(dose));
  }

  // ---------- helpers ----------

  private record Cancellation(Object resource, String reason) {}

  private IdempotencyCoordinator.AuditContext auditContext(
      UUID actorId, AuditAction action, AuditResourceType resourceType) {
    AuthorizedUser actor = identity.resolve(actorId);
    return new IdempotencyCoordinator.AuditContext(
        actor.getId(), institution(actor), action, resourceType);
  }

  private UUID institution(AuthorizedUser actor) {
    return dataScope.institutionOf(actor);
  }

  private void requirePatientScoped(UUID institutionId, UUID patientId) {
    if (!patientScope.existsInInstitution(patientId, institutionId)) {
      throw new PatientNotFoundException("El paciente no existe o no pertenece a tu institucion.");
    }
  }

  private AttentionEntity requireScoped(AuthorizedUser actor, UUID attentionId) {
    UUID institutionId = institution(actor);
    return attentions
        .findByIdAndInstitutionId(attentionId, institutionId)
        .orElseThrow(() -> new AttentionNotFoundException(
            "La atencion no existe o no pertenece a tu institucion."));
  }

  private void requireEditable(AttentionEntity attention) {
    if (!attention.isEditable()) {
      throw new InvalidClinicalStateException(
          "La atencion no se puede modificar en su estado actual (" + attention.getStatus() + ").");
    }
  }

  private AttentionResponse response(AttentionEntity attention) {
    List<AppliedDoseResponse> doseResponses =
        doses.findByAttentionIdOrderByCreatedAtAsc(attention.getId()).stream()
            .map(mapper::toDoseResponse)
            .toList();
    return mapper.toResponse(attention, doseResponses);
  }

  /**
   * Dosis de todas las atenciones en una sola consulta, agrupadas por atencion.
   * Evita el N+1 de {@link #response(AttentionEntity)} al listar.
   */
  private Map<UUID, List<AppliedDoseResponse>> doseResponsesByAttention(
      List<AttentionEntity> found) {
    if (found.isEmpty()) {
      return Map.of();
    }
    List<UUID> attentionIds = found.stream().map(AttentionEntity::getId).toList();
    Map<UUID, List<AppliedDoseResponse>> grouped = new LinkedHashMap<>();
    for (AppliedDoseEntity dose : doses.findByAttentionIdInOrderByCreatedAtAsc(attentionIds)) {
      grouped
          .computeIfAbsent(dose.getAttentionId(), key -> new ArrayList<>())
          .add(mapper.toDoseResponse(dose));
    }
    return grouped;
  }
}
