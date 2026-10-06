package com.pai.api.synchronization.service.command;

import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;

/**
 * Handler de un comando de sincronizacion (Strategy). Cada comando implementa
 * su tipo, el permiso que exige y como aplicarlo en el servicio de dominio.
 *
 * <p>Agregar un comando nuevo es una clase nueva (OCP): {@link
 * com.pai.api.synchronization.service.SyncPushService} no cambia.
 */
public interface SyncCommandHandler {

  /** {@code commandType} del comando que atiende. */
  String commandType();

  /** Permiso requerido, o {@code null} si el comando no exige permiso. */
  String permission();

  /** Aplica el comando. Las excepciones de dominio las clasifica el orquestador. */
  void apply(UUID actorId, String operationId, SyncOperation operation);
}
