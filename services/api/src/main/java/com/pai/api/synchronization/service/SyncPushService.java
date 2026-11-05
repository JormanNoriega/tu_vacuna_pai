package com.pai.api.synchronization.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.shared.application.ProcessedOperationsPort;
import com.pai.api.shared.util.Strings;
import com.pai.api.synchronization.dto.RejectedOperation;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.dto.SyncPushRequest;
import com.pai.api.synchronization.dto.SyncPushResponse;
import com.pai.api.synchronization.service.chain.SyncAdmissionChain;
import com.pai.api.synchronization.service.chain.SyncOperationContext;
import com.pai.api.synchronization.service.chain.SyncOperationResult;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Procesa un batch de {@code /sync/push}.
 *
 * <p>Aplica el patron de comportamiento **Chain of Responsibility** para validar
 * y admitir cada operacion a traves de una secuencia desacoplada de eslabones
 * (dependencias, idempotencia, soporte de comando, autorizacion y ejecucion de dominio).
 *
 * <p>La atomicidad es por operacion (no por batch): cada comando se aplica en la
 * transaccion propia del servicio de dominio. No se anota {@code @Transactional}
 * aqui a proposito, para que un rechazo no revierta las operaciones ya aceptadas.
 */
@Service
public class SyncPushService {

  private final IdentityService identity;
  private final Map<String, SyncCommandHandler> handlers;
  private final SyncAdmissionChain admissionChain;

  @Autowired
  public SyncPushService(
      IdentityService identity,
      SyncAdmissionChain admissionChain,
      List<SyncCommandHandler> commandHandlers) {
    this.identity = identity;
    this.admissionChain = admissionChain;
    this.handlers = commandHandlers.stream()
        .collect(
            Collectors.toUnmodifiableMap(SyncCommandHandler::commandType, Function.identity()));
  }

  public SyncPushService(
      IdentityService identity,
      PatientMergeRequestService mergeRequests,
      ProcessedOperationsPort processedOperations,
      List<SyncCommandHandler> commandHandlers) {
    this(
        identity,
        SyncAdmissionChain.buildDefault(processedOperations, mergeRequests),
        commandHandlers);
  }

  public SyncPushResponse push(UUID actorId, SyncPushRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    List<UUID> accepted = new ArrayList<>();
    List<RejectedOperation> rejected = new ArrayList<>();
    // Resultado por operationId dentro del batch: true aceptada, false rechazada.
    Map<UUID, Boolean> outcomes = new HashMap<>();

    for (SyncOperation operation : Strings.safe(request.operations())) {
      UUID operationId = operation.operationId();
      SyncOperationContext context = new SyncOperationContext(
          actorId,
          actor,
          operation,
          Collections.unmodifiableMap(outcomes),
          handlers);

      SyncOperationResult result = admissionChain.process(context);
      if (result.accepted()) {
        accepted.add(operationId);
        outcomes.put(operationId, true);
      } else {
        rejected.add(result.rejection());
        outcomes.put(operationId, false);
      }
    }

    return new SyncPushResponse(accepted, rejected);
  }
}
