package com.pai.api.identity.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

public class EmailAlreadyExistsException extends DomainRuntimeException {

  public EmailAlreadyExistsException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "EMAIL_ALREADY_EXISTS";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
