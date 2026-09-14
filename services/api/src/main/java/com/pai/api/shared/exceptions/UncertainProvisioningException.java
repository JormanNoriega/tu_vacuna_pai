package com.pai.api.shared.exceptions;

/**
 * Resultado incierto de una llamada al servicio de identidad (timeout, 5xx o
 * respuesta sin id). Supabase pudo crear el auth.user aunque el cliente no lo
 * confirme. La operacion queda en {@code UNCERTAIN} y se resuelve por
 * correlacion de {@code operation_id} en vez de asumir el resultado.
 */
public class UncertainProvisioningException extends RuntimeException {

  public UncertainProvisioningException(String message) {
    super(message);
  }

  public UncertainProvisioningException(String message, Throwable cause) {
    super(message, cause);
  }
}
