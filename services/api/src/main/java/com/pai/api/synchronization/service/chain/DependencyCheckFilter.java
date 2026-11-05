package com.pai.api.synchronization.service.chain;

import com.pai.api.shared.application.ProcessedOperationsPort;
import com.pai.api.shared.util.Strings;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.Map;
import java.util.UUID;

/**
 * Eslabon 1 de la cadena de admision:
 * Valida que todas las dependencias causales de la operacion esten satisfechas.
 * Si una dependencia previa en el mismo lote fallo, o si no existe ni en el lote
 * ni en el registro historico de operaciones procesadas, la cadena se cortocircuita
 * y la operacion se rechaza.
 */
public class DependencyCheckFilter extends AbstractSyncOperationFilter {

  public static final String REASON_DEPENDENCY_NOT_FOUND = "DEPENDENCY_NOT_FOUND";
  public static final String REASON_DEPENDENCY_FAILED = "DEPENDENCY_FAILED";

  private final ProcessedOperationsPort processedOperations;

  public DependencyCheckFilter(ProcessedOperationsPort processedOperations) {
    this.processedOperations = processedOperations;
  }

  @Override
  protected SyncOperationResult handleCurrent(SyncOperationContext context) {
    SyncOperation operation = context.operation();
    Map<UUID, Boolean> outcomes = context.batchOutcomes();

    for (UUID dependency : Strings.safe(operation.dependencies())) {
      Boolean outcome = outcomes.get(dependency);
      if (outcome != null && !outcome) {
        return SyncOperationResult.reject(
            operation.operationId(),
            REASON_DEPENDENCY_FAILED,
            "Dependencia no satisfecha.");
      }
      if (outcome == null && !processedOperations.exists(dependency.toString())) {
        return SyncOperationResult.reject(
            operation.operationId(),
            REASON_DEPENDENCY_NOT_FOUND,
            "Dependencia no satisfecha.");
      }
    }

    return proceed(context);
  }
}
