package com.pai.api.identity.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

public class InstitutionCodeAlreadyExistsException extends DomainRuntimeException {

  public InstitutionCodeAlreadyExistsException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "INSTITUTION_CODE_ALREADY_EXISTS";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
