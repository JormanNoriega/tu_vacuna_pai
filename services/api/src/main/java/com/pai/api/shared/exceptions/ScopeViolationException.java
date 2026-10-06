package com.pai.api.shared.exceptions;

import org.springframework.http.HttpStatus;

/** El actor intenta acceder a un recurso fuera de su alcance institucional. */
public class ScopeViolationException extends DomainRuntimeException {

  public ScopeViolationException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "SCOPE_VIOLATION";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.FORBIDDEN;
  }
}
