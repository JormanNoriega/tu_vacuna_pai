package com.pai.api.catalog.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/** Conflicto de bloqueo optimista: el recurso fue modificado por otro usuario. */
public class OptimisticCatalogException extends DomainRuntimeException {

  public OptimisticCatalogException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "OPTIMISTIC_LOCK_CONFLICT";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
