package com.pai.api.patients.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/** El paciente no existe o esta fuera del alcance de la institucion del actor. */
public class PatientNotFoundException extends DomainRuntimeException {

  public PatientNotFoundException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "PATIENT_NOT_FOUND";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.NOT_FOUND;
  }
}
