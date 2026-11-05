package com.pai.api.synchronization.service.chain;

import com.pai.api.shared.application.ProcessedOperationsPort;
import java.util.UUID;

/**
 * Eslabon 2 de la cadena de admision:
 * Verifica si la operacion ya fue persistida y ejecutada previamente (idempotencia).
 * Si la operacion ya existe, se acepta de inmediato y se cortocircuita la cadena,
 * evitando reprocesamiento o duplicacion de efectos colaterales de negocio.
 */
public class IdempotencyCheckFilter extends AbstractSyncOperationFilter {

  private final ProcessedOperationsPort processedOperations;

  public IdempotencyCheckFilter(ProcessedOperationsPort processedOperations) {
    this.processedOperations = processedOperations;
  }

  @Override
  protected SyncOperationResult handleCurrent(SyncOperationContext context) {
    UUID operationId = context.operation().operationId();
    if (processedOperations.exists(operationId.toString())) {
      // Idempotencia: ya fue procesada con exito anteriormente, no requiere re-ejecutar.
      return SyncOperationResult.accept();
    }
    return proceed(context);
  }
}
