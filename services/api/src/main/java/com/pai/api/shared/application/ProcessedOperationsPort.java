package com.pai.api.shared.application;

import java.util.Optional;
import java.util.UUID;

/**
 * Puerto (DIP) de idempotencia de comandos: recupera la respuesta de una
 * operacion ya procesada y registra una nueva. Lo define {@code shared} y lo
 * implementa {@code synchronization}, de modo que {@link IdempotencyCoordinator}
 * no depende del servicio concreto de sincronizacion.
 */
public interface ProcessedOperationsPort {

  /** Respuesta original de una operacion ya procesada, si existe. */
  <T> Optional<T> find(String operationId, Class<T> type);

  /** Indica si el {@code operation_id} ya fue procesado con exito (idempotencia). */
  boolean exists(String operationId);

  /** Registra la respuesta de una operacion procesada (payload y respuesta). */
  void record(
      String operationId,
      String commandType,
      UUID aggregateId,
      UUID institutionId,
      Object payload,
      Object response);
}
