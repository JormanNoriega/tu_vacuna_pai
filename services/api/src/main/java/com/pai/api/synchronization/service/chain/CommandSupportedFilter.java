package com.pai.api.synchronization.service.chain;

import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import java.util.UUID;

/**
 * Eslabon 3 de la cadena de admision:
 * Comprueba que exista un manejador (SyncCommandHandler) registrado para el tipo
 * de comando solicitado. Si no existe, rechaza la operacion como INVALID_PAYLOAD.
 * Si existe, guarda la referencia resuelta en el contexto para los eslabones siguientes.
 */
public class CommandSupportedFilter extends AbstractSyncOperationFilter {

  public static final String REASON_INVALID_PAYLOAD = "INVALID_PAYLOAD";

  @Override
  protected SyncOperationResult handleCurrent(SyncOperationContext context) {
    SyncOperation operation = context.operation();
    UUID operationId = operation.operationId();
    SyncCommandHandler handler = context.handlers().get(operation.commandType());

    if (handler == null) {
      return SyncOperationResult.reject(
          operationId,
          REASON_INVALID_PAYLOAD,
          "Comando no soportado: " + operation.commandType());
    }

    context.setResolvedHandler(handler);
    return proceed(context);
  }
}
