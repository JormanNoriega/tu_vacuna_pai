package com.pai.api.synchronization.service.chain;

import com.pai.api.synchronization.dto.RejectedOperation;
import java.util.UUID;

/**
 * Representa el resultado de la evaluacion de un eslabon de la cadena
 * de admision para una operacion de sincronizacion.
 */
public record SyncOperationResult(boolean accepted, RejectedOperation rejection) {

  public static SyncOperationResult accept() {
    return new SyncOperationResult(true, null);
  }

  public static SyncOperationResult reject(UUID operationId, String reason, String error) {
    return new SyncOperationResult(false, new RejectedOperation(operationId, reason, error));
  }
}
