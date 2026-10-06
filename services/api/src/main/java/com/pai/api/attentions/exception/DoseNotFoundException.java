package com.pai.api.attentions.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/** La dosis aplicada no existe dentro de la atencion indicada. */
public class DoseNotFoundException extends DomainRuntimeException {

  public DoseNotFoundException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "DOSE_NOT_FOUND";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.NOT_FOUND;
  }
}
