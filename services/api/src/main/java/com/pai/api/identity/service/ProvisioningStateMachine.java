package com.pai.api.identity.service;

import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.exception.EmailAlreadyExistsException;
import com.pai.api.identity.exception.ProvisioningPendingException;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;

/**
 * Maquina de estados de {@link ProvisioningOperationEntity}: resuelve o crea la
 * operacion por {@code operationId} y ejecuta transiciones con guarda. Extraida
 * de {@link UserProvisioningService} (SRP): la orquestacion remota/espejo no
 * conoce las reglas de idempotencia ni el ciclo de vida del estado.
 */
@Component
public class ProvisioningStateMachine {

  private static final Set<ProvisioningOperationStatus> ADOPTABLE_FROM =
      Set.of(ProvisioningOperationStatus.PENDING, ProvisioningOperationStatus.UNCERTAIN);

  private final ProvisioningOperationRepository operationRepository;

  public ProvisioningStateMachine(ProvisioningOperationRepository operationRepository) {
    this.operationRepository = operationRepository;
  }

  /** Carga la operacion por {@code operationId}, si existe. */
  public Optional<ProvisioningOperationEntity> find(UUID operationId) {
    return operationRepository.findById(operationId);
  }

  /**
   * Carga la operacion por {@code operationId} o la crea en {@code PENDING}.
   * Aplica las reglas de idempotencia de reintentos.
   */
  public ProvisioningOperationEntity resolveOrStart(
      UUID operationId,
      String email,
      String fullName,
      UUID institutionId,
      String roleCode,
      UUID actorId,
      AuthUserProfile profile) {
    ProvisioningOperationEntity op = operationRepository.findById(operationId).orElse(null);
    if (op == null) {
      return start(operationId, email, fullName, institutionId, roleCode, actorId, profile);
    }

    if (!op.getEmail().equals(email)) {
      throw new IllegalArgumentException("La operacion ya fue registrada con otro correo.");
    }
    if (profile != null
        && op.getDocumentNumber() != null
        && !op.getDocumentNumber().equals(profile.documentNumber())) {
      throw new IllegalArgumentException("La operacion ya fue registrada con otro documento.");
    }

    switch (op.getStatus()) {
      case COMPLETED -> {
        // Se repliega en provision() con el resultado ya persistido.
      }
      case REJECTED ->
        throw new EmailAlreadyExistsException("Ya existe un usuario con ese correo.");
      case COMPENSATION_FAILED ->
        throw new ProvisioningPendingException(
            "La creacion quedo pendiente de compensacion. Revisa la reconciliacion.");
      case COMPENSATING ->
        throw new ProvisioningPendingException("La operacion esta en proceso de compensacion.");
      case COMPENSATED -> {
        // El auth.user ya se borro: el correo quedo libre; se reintenta.
        op.resetForRetry(Instant.now());
        operationRepository.save(op);
      }
      default -> {
        // PENDING, AUTH_CREATED, UNCERTAIN: se continua en provision().
      }
    }
    return op;
  }

  /**
   * Registra el auth.user creado y avanza a {@code AUTH_CREATED}. Devuelve
   * false si la operacion ya avanzo (concurrencia).
   */
  public boolean adoptAuthUser(ProvisioningOperationEntity op, UUID authUserId) {
    Instant now = Instant.now();
    int adopted =
        operationRepository.adoptAuthUser(op.getOperationId(), ADOPTABLE_FROM, authUserId, now);
    if (adopted == 0) {
      return false;
    }
    op.applyTransition(ProvisioningOperationStatus.AUTH_CREATED, authUserId, null, now);
    return true;
  }

  /**
   * Transicion con guarda de estado. Devuelve false si el estado ya avanzo.
   */
  public boolean transition(
      ProvisioningOperationEntity op,
      ProvisioningOperationStatus from,
      ProvisioningOperationStatus to,
      UUID authUserId,
      String error) {
    Instant now = Instant.now();
    int rows =
        operationRepository.transition(op.getOperationId(), from, to, authUserId, error, now);
    if (rows == 0) {
      return false;
    }
    op.applyTransition(to, authUserId, error, now);
    return true;
  }

  private ProvisioningOperationEntity start(
      UUID operationId,
      String email,
      String fullName,
      UUID institutionId,
      String roleCode,
      UUID actorId,
      AuthUserProfile profile) {
    Instant now = Instant.now();
    ProvisioningOperationEntity op = new ProvisioningOperationEntity(
        operationId,
        null,
        email,
        fullName,
        institutionId,
        roleCode,
        actorId,
        ProvisioningOperationStatus.PENDING,
        (short) 1,
        null,
        now,
        now,
        profile == null ? null : profile.documentType(),
        profile == null ? null : profile.documentNumber(),
        profile == null ? null : profile.phone(),
        profile == null ? null : profile.birthDate(),
        profile == null ? null : profile.gender(),
        profile == null ? null : profile.professionCode(),
        profile == null ? null : profile.professionalRegistrationNumber(),
        profile == null ? null : profile.professionalRegistrationType());
    try {
      return operationRepository.save(op);
    } catch (DataIntegrityViolationException ex) {
      // Concurrencia: otro request inserto la misma operacion.
      ProvisioningOperationEntity existing =
          operationRepository.findById(operationId).orElseThrow();
      if (existing.getEmail().equals(email)) {
        return existing;
      }
      throw ex;
    }
  }
}
