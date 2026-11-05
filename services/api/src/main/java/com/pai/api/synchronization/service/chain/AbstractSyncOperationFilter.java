package com.pai.api.synchronization.service.chain;

/**
 * Clase base abstracta que gestiona la referencia al siguiente eslabon
 * y el mecanismo estandar de propagacion (proceed) a traves de la cadena.
 */
public abstract class AbstractSyncOperationFilter implements SyncOperationFilter {

  private SyncOperationFilter next;

  @Override
  public SyncOperationFilter setNext(SyncOperationFilter next) {
    this.next = next;
    return next;
  }

  @Override
  public SyncOperationResult handle(SyncOperationContext context) {
    return handleCurrent(context);
  }

  /**
   * Logica de validacion o ejecucion especifica del eslabon concreto.
   */
  protected abstract SyncOperationResult handleCurrent(SyncOperationContext context);

  /**
   * Pasa el control al siguiente filtro en la cadena. Si es el ultimo
   * eslabon y no hubo rechazos, la operacion se considera aceptada.
   */
  protected SyncOperationResult proceed(SyncOperationContext context) {
    if (next != null) {
      return next.handle(context);
    }
    return SyncOperationResult.accept();
  }
}
