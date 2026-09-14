package com.pai.api.patients.exception;

/** El paciente no existe o esta fuera del alcance de la institucion del actor. */
public class PatientNotFoundException extends RuntimeException {

  public PatientNotFoundException(String message) {
    super(message);
  }
}
