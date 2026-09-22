package com.pai.api.attentions.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/** La atencion no existe o esta fuera del alcance de la institucion del actor. */
public class AttentionNotFoundException extends DomainRuntimeException {

  public AttentionNotFoundException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "ATTENTION_NOT_FOUND";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.NOT_FOUND;
  }
}
