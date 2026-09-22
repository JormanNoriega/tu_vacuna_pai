package com.pai.api.identity.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

public class InstitutionNotFoundException extends DomainRuntimeException {

  public InstitutionNotFoundException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "INSTITUTION_NOT_FOUND";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.NOT_FOUND;
  }
}
