package com.pai.api.synchronization.service.chain;

/**
 * Interfaz base del manejador (Handler) para el patron Chain of Responsibility.
 * Cada filtro evalua una condicion de admision de la operacion de sincronizacion
 * o la procesa, delegando en el siguiente eslabon si se cumplen los requisitos.
 */
public interface SyncOperationFilter {

  /**
   * Configura el siguiente eslabon en la cadena y lo retorna para permitir
   * encadenamiento fluido (method chaining).
   */
  SyncOperationFilter setNext(SyncOperationFilter next);

  /**
   * Procesa el contexto actual o delega al siguiente filtro.
   */
  SyncOperationResult handle(SyncOperationContext context);
}
