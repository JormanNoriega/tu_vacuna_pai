package com.pai.api.identity.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

public class UserNotActiveException extends DomainRuntimeException {

  public UserNotActiveException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "USER_NOT_ACTIVE";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.FORBIDDEN;
  }
}
