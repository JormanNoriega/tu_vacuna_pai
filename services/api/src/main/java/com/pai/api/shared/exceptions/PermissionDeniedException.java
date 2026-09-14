package com.pai.api.shared.exceptions;

/**
 * El usuario autenticado no posee el permiso requerido para la operacion.
 * Representa la segunda barrera de autorizacion en el servicio: el permiso se
 * valida en el controller ({@code @PreAuthorize}) y se revalida en el servicio
 * para que ninguna llamada directa pueda saltarse la regla.
 */
public class PermissionDeniedException extends RuntimeException {

  public PermissionDeniedException(String message) {
    super(message);
  }
}
