package com.pai.api.synchronization.service.chain;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import java.util.Map;
import java.util.UUID;

/**
 * Contexto transversal que viaja a traves de los eslabones de la cadena
 * de admision (Chain of Responsibility) para una operacion de sincronizacion.
 */
public class SyncOperationContext {

  private final UUID actorId;
  private final AuthorizedUser actor;
  private final SyncOperation operation;
  private final Map<UUID, Boolean> batchOutcomes;
  private final Map<String, SyncCommandHandler> handlers;
  private SyncCommandHandler resolvedHandler;

  public SyncOperationContext(
      UUID actorId,
      AuthorizedUser actor,
      SyncOperation operation,
      Map<UUID, Boolean> batchOutcomes,
      Map<String, SyncCommandHandler> handlers) {
    this.actorId = actorId;
    this.actor = actor;
    this.operation = operation;
    this.batchOutcomes = batchOutcomes;
    this.handlers = handlers;
  }

  public UUID actorId() {
    return actorId;
  }

  public AuthorizedUser actor() {
    return actor;
  }

  public SyncOperation operation() {
    return operation;
  }

  public Map<UUID, Boolean> batchOutcomes() {
    return batchOutcomes;
  }

  public Map<String, SyncCommandHandler> handlers() {
    return handlers;
  }

  public SyncCommandHandler resolvedHandler() {
    return resolvedHandler;
  }

  public void setResolvedHandler(SyncCommandHandler resolvedHandler) {
    this.resolvedHandler = resolvedHandler;
  }
}
