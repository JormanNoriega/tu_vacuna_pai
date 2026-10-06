package com.pai.api.identity.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

public class UserNotFoundException extends DomainRuntimeException {

  public UserNotFoundException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "USER_NOT_FOUND";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.NOT_FOUND;
  }
}
