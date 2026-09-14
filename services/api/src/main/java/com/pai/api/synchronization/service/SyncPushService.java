package com.pai.api.synchronization.service;

import com.pai.api.attentions.dto.CreateAttentionRequest;
import com.pai.api.attentions.dto.RegisterDoseRequest;
import com.pai.api.attentions.exception.AttentionNotFoundException;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.attentions.service.AttentionService;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.patients.service.PatientService;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.shared.exceptions.UserNotActiveException;
import com.pai.api.synchronization.dto.RejectedOperation;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.dto.SyncPushRequest;
import com.pai.api.synchronization.dto.SyncPushResponse;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

/**
 * Procesa un batch de {@code /sync/push}. Es un **despachador delgado**: no
 * reimplementa reglas de dominio, delega en {@link PatientService} y
 * {@link AttentionService}, los mismos servicios del transporte REST directo
 * (misma idempotencia, misma auditoria).
 *
 * <p>La atomicidad es por operacion (no por batch): cada comando se aplica en la
 * transaccion propia del servicio de dominio. No se anota {@code @Transactional}
 * aqui a proposito, para que un rechazo no revierta las operaciones ya aceptadas.
 */
@Service
public class SyncPushService {

  private static final String CREATE_PATIENT = "CREATE_PATIENT";
  private static final String CREATE_ATTENTION = "CREATE_ATTENTION";
  private static final String REGISTER_APPLIED_DOSE = "REGISTER_APPLIED_DOSE";
  private static final String COMPLETE_ATTENTION = "COMPLETE_ATTENTION";

  private static final String PERMISSION_PATIENT_WRITE = "PATIENT_WRITE";
  private static final String PERMISSION_ATTENTION_CREATE = "ATTENTION_CREATE";

  private static final String REASON_DEPENDENCY_NOT_FOUND = "DEPENDENCY_NOT_FOUND";
  private static final String REASON_DEPENDENCY_FAILED = "DEPENDENCY_FAILED";
  private static final String REASON_DUPLICATE = "DUPLICATE_BUSINESS_IDENTITY";
  private static final String REASON_PERMISSION_DENIED = "PERMISSION_DENIED";
  private static final String REASON_USER_NOT_ACTIVE = "USER_NOT_ACTIVE";
  private static final String REASON_INVALID_STATE = "INVALID_STATE";
  private static final String REASON_INVALID_PAYLOAD = "INVALID_PAYLOAD";

  private final PatientService patients;
  private final AttentionService attentions;
  private final PatientMergeRequestService mergeRequests;
  private final IdentityService identity;
  private final ProcessedOperationsService processedOperations;
  private final ObjectMapper mapper;

  public SyncPushService(
      PatientService patients,
      AttentionService attentions,
      PatientMergeRequestService mergeRequests,
      IdentityService identity,
      ProcessedOperationsService processedOperations,
      ObjectMapper mapper) {
    this.patients = patients;
    this.attentions = attentions;
    this.mergeRequests = mergeRequests;
    this.identity = identity;
    this.processedOperations = processedOperations;
    this.mapper = mapper;
  }

  public SyncPushResponse push(UUID actorId, SyncPushRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    List<UUID> accepted = new ArrayList<>();
    List<RejectedOperation> rejected = new ArrayList<>();
    // Resultado por operationId dentro del batch: true aceptada, false rechazada.
    Map<UUID, Boolean> outcomes = new HashMap<>();

    for (SyncOperation operation : safe(request.operations())) {
      UUID operationId = operation.operationId();

      String dependencyReason = dependencyRejection(operation, outcomes);
      if (dependencyReason != null) {
        reject(rejected, outcomes, operationId, dependencyReason, "Dependencia no satisfecha.");
        continue;
      }

      if (processedOperations.exists(operationId.toString())) {
        accepted.add(operationId);
        outcomes.put(operationId, true);
        continue;
      }

      String permission = permissionFor(operation.commandType());
      if (permission != null && !actor.getPermissions().contains(permission)) {
        reject(
            rejected,
            outcomes,
            operationId,
            REASON_PERMISSION_DENIED,
            "El permiso actual no autoriza la operacion.");
        continue;
      }

      try {
        dispatch(actorId, operation);
        accepted.add(operationId);
        outcomes.put(operationId, true);
      } catch (PatientAlreadyExistsException ex) {
        mergeRequests.requestReview(ex.getExistingPatientId());
        reject(rejected, outcomes, operationId, REASON_DUPLICATE, ex.getMessage());
      } catch (PatientNotFoundException | AttentionNotFoundException ex) {
        reject(rejected, outcomes, operationId, REASON_DEPENDENCY_NOT_FOUND, ex.getMessage());
      } catch (InvalidClinicalStateException ex) {
        reject(rejected, outcomes, operationId, REASON_INVALID_STATE, ex.getMessage());
      } catch (PermissionDeniedException | ScopeViolationException ex) {
        reject(rejected, outcomes, operationId, REASON_PERMISSION_DENIED, ex.getMessage());
      } catch (UserNotActiveException ex) {
        reject(rejected, outcomes, operationId, REASON_USER_NOT_ACTIVE, ex.getMessage());
      } catch (IllegalArgumentException ex) {
        reject(rejected, outcomes, operationId, REASON_INVALID_PAYLOAD, ex.getMessage());
      }
    }

    return new SyncPushResponse(accepted, rejected);
  }

  private void dispatch(UUID actorId, SyncOperation operation) {
    String operationId = operation.operationId().toString();
    switch (operation.commandType()) {
      case CREATE_PATIENT ->
        patients.create(
            actorId,
            operationId,
            operation.aggregateId(),
            convert(operation, CreatePatientRequest.class));
      case CREATE_ATTENTION ->
        attentions.create(
            actorId,
            operationId,
            operation.aggregateId(),
            convert(operation, CreateAttentionRequest.class));
      case REGISTER_APPLIED_DOSE ->
        attentions.registerDose(
            actorId,
            operationId,
            attentionId(operation),
            operation.aggregateId(),
            convertDose(operation));
      case COMPLETE_ATTENTION -> attentions.complete(actorId, operationId, operation.aggregateId());
      default ->
        throw new IllegalArgumentException("Comando no soportado: " + operation.commandType());
    }
  }

  /**
   * Indica por que se rechaza la operacion por dependencias: {@code null} si
   * todas estan satisfechas, {@code DEPENDENCY_FAILED} si una fallo en el batch
   * o {@code DEPENDENCY_NOT_FOUND} si no existe ni en el batch ni en el log.
   */
  private String dependencyRejection(SyncOperation operation, Map<UUID, Boolean> outcomes) {
    for (UUID dependency : safe(operation.dependencies())) {
      Boolean outcome = outcomes.get(dependency);
      if (outcome != null && !outcome) {
        return REASON_DEPENDENCY_FAILED;
      }
      if (outcome == null && !processedOperations.exists(dependency.toString())) {
        return REASON_DEPENDENCY_NOT_FOUND;
      }
    }
    return null;
  }

  private <T> T convert(SyncOperation operation, Class<T> type) {
    return mapper.convertValue(safe(operation.payload()), type);
  }

  private RegisterDoseRequest convertDose(SyncOperation operation) {
    Map<String, Object> payload = new HashMap<>(safe(operation.payload()));
    // attentionId viaja en el payload del comando; no es parte del DTO REST.
    payload.remove("attentionId");
    return mapper.convertValue(payload, RegisterDoseRequest.class);
  }

  private UUID attentionId(SyncOperation operation) {
    Object value = safe(operation.payload()).get("attentionId");
    if (value == null) {
      throw new IllegalArgumentException("El payload de la dosis requiere attentionId.");
    }
    try {
      return UUID.fromString(value.toString());
    } catch (IllegalArgumentException ex) {
      throw new IllegalArgumentException("attentionId invalido.");
    }
  }

  private String permissionFor(String commandType) {
    return switch (commandType) {
      case CREATE_PATIENT -> PERMISSION_PATIENT_WRITE;
      case CREATE_ATTENTION, REGISTER_APPLIED_DOSE, COMPLETE_ATTENTION ->
        PERMISSION_ATTENTION_CREATE;
      default -> null;
    };
  }

  private void reject(
      List<RejectedOperation> rejected,
      Map<UUID, Boolean> outcomes,
      UUID operationId,
      String reason,
      String error) {
    rejected.add(new RejectedOperation(operationId, reason, error));
    outcomes.put(operationId, false);
  }

  private static <T> List<T> safe(List<T> list) {
    return list == null ? List.of() : list;
  }

  private static Map<String, Object> safe(Map<String, Object> map) {
    return map == null ? Map.of() : map;
  }
}
