package com.pai.api.identity.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/**
 * La operacion de aprovisionamiento sigue pendiente o en curso (p. ej. una
 * compensacion fallida o un reintento mientras otro request avanza la misma
 * operacion). El cliente debe reintentar o revisar la reconciliacion; nunca se
 * interpreta como un duplicado de correo.
 */
public class ProvisioningPendingException extends DomainRuntimeException {

  public ProvisioningPendingException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "OPERATION_IN_PROGRESS";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
