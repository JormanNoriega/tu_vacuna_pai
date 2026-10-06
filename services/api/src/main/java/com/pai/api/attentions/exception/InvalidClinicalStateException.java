package com.pai.api.attentions.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/**
 * Transicion o mutacion invalida del agregado clinico (p. ej. editar una
 * atencion {@code COMPLETED}, registrar una dosis en una atencion anulada, o
 * cancelar una dosis ya cancelada). Mapea a {@code 409 INVALID_STATE}.
 */
public class InvalidClinicalStateException extends DomainRuntimeException {

  public InvalidClinicalStateException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "INVALID_STATE";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
