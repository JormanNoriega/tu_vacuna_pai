package com.pai.api.synchronization.service.chain;

import com.pai.api.synchronization.service.command.SyncCommandHandler;

/**
 * Eslabon 4 de la cadena de admision:
 * Evalua si el usuario autenticado (actor) posee el permiso requerido por el
 * manejador del comando. Si carece del permiso, cortocircuita y rechaza con
 * PERMISSION_DENIED.
 */
public class PermissionCheckFilter extends AbstractSyncOperationFilter {

  public static final String REASON_PERMISSION_DENIED = "PERMISSION_DENIED";

  @Override
  protected SyncOperationResult handleCurrent(SyncOperationContext context) {
    SyncCommandHandler handler = context.resolvedHandler();
    String permission = handler.permission();

    if (permission != null && !context.actor().hasPermission(permission)) {
      return SyncOperationResult.reject(
          context.operation().operationId(),
          REASON_PERMISSION_DENIED,
          "El permiso actual no autoriza la operacion.");
    }

    return proceed(context);
  }
}
