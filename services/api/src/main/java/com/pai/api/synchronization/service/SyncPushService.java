package com.pai.api.synchronization.service;

import com.pai.api.attentions.exception.AttentionNotFoundException;
import com.pai.api.attentions.exception.InvalidCatalogSelectionException;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.identity.exception.UserNotActiveException;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.shared.application.ProcessedOperationsPort;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.shared.util.Strings;
import com.pai.api.synchronization.dto.RejectedOperation;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.dto.SyncPushRequest;
import com.pai.api.synchronization.dto.SyncPushResponse;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Procesa un batch de {@code /sync/push}. Es un **despachador delgado**: no
 * reimplementa reglas de dominio; delega en un {@link SyncCommandHandler} por
 * comando (Strategy), que a su vez invoca el mismo servicio de dominio del
 * transporte REST directo (misma idempotencia, misma auditoria).
 *
 * <p>Agregar un comando nuevo es una clase nueva (OCP); este orquestador solo
 * mantiene lo transversal al batch: dependencias, resultados por operacion y la
 * clasificacion de excepciones de dominio en motivos de rechazo.
 *
 * <p>La atomicidad es por operacion (no por batch): cada comando se aplica en la
 * transaccion propia del servicio de dominio. No se anota {@code @Transactional}
 * aqui a proposito, para que un rechazo no revierta las operaciones ya aceptadas.
 */
@Service
public class SyncPushService {

  private static final String REASON_DEPENDENCY_NOT_FOUND = "DEPENDENCY_NOT_FOUND";
  private static final String REASON_DEPENDENCY_FAILED = "DEPENDENCY_FAILED";
  private static final String REASON_DUPLICATE = "DUPLICATE_BUSINESS_IDENTITY";
  private static final String REASON_PERMISSION_DENIED = "PERMISSION_DENIED";
  private static final String REASON_USER_NOT_ACTIVE = "USER_NOT_ACTIVE";
  private static final String REASON_INVALID_STATE = "INVALID_STATE";
  private static final String REASON_INVALID_PAYLOAD = "INVALID_PAYLOAD";

  private final IdentityService identity;
  private final PatientMergeRequestService mergeRequests;
  private final ProcessedOperationsPort processedOperations;
  private final Map<String, SyncCommandHandler> handlers;

  public SyncPushService(
      IdentityService identity,
      PatientMergeRequestService mergeRequests,
      ProcessedOperationsPort processedOperations,
      List<SyncCommandHandler> commandHandlers) {
    this.identity = identity;
    this.mergeRequests = mergeRequests;
    this.processedOperations = processedOperations;
    this.handlers = commandHandlers.stream()
        .collect(
            Collectors.toUnmodifiableMap(SyncCommandHandler::commandType, Function.identity()));
  }

  public SyncPushResponse push(UUID actorId, SyncPushRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    List<UUID> accepted = new ArrayList<>();
    List<RejectedOperation> rejected = new ArrayList<>();
    // Resultado por operationId dentro del batch: true aceptada, false rechazada.
    Map<UUID, Boolean> outcomes = new HashMap<>();

    for (SyncOperation operation : Strings.safe(request.operations())) {
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

      SyncCommandHandler handler = handlers.get(operation.commandType());
      if (handler == null) {
        reject(
            rejected,
            outcomes,
            operationId,
            REASON_INVALID_PAYLOAD,
            "Comando no soportado: " + operation.commandType());
        continue;
      }

      String permission = handler.permission();
      if (permission != null && !actor.hasPermission(permission)) {
        reject(
            rejected,
            outcomes,
            operationId,
            REASON_PERMISSION_DENIED,
            "El permiso actual no autoriza la operacion.");
        continue;
      }

      try {
        handler.apply(actorId, operationId.toString(), operation);
        accepted.add(operationId);
        outcomes.put(operationId, true);
      } catch (PatientAlreadyExistsException ex) {
        mergeRequests.requestReview(ex.getExistingPatientId());
        reject(rejected, outcomes, operationId, REASON_DUPLICATE, ex.getMessage());
      } catch (PatientNotFoundException | AttentionNotFoundException ex) {
        reject(rejected, outcomes, operationId, REASON_DEPENDENCY_NOT_FOUND, ex.getMessage());
      } catch (InvalidClinicalStateException | InvalidCatalogSelectionException ex) {
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

  /**
   * Indica por que se rechaza la operacion por dependencias: {@code null} si
   * todas estan satisfechas, {@code DEPENDENCY_FAILED} si una fallo en el batch
   * o {@code DEPENDENCY_NOT_FOUND} si no existe ni en el batch ni en el log.
   */
  private String dependencyRejection(SyncOperation operation, Map<UUID, Boolean> outcomes) {
    for (UUID dependency : Strings.safe(operation.dependencies())) {
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

  private void reject(
      List<RejectedOperation> rejected,
      Map<UUID, Boolean> outcomes,
      UUID operationId,
      String reason,
      String error) {
    rejected.add(new RejectedOperation(operationId, reason, error));
    outcomes.put(operationId, false);
  }
}
