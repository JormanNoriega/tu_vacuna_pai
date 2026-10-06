package com.pai.api.shared.exceptions;

import org.springframework.http.HttpStatus;

/**
 * Contrato de una excepcion de dominio: codigo de error estable (consumido por
 * el cliente) y status HTTP. Permite que el {@code GlobalExceptionHandler}
 * responda de forma polimorfica (OCP) sin conocer cada tipo.
 */
public interface DomainException {

  /** Codigo de error estable de la API (p. ej. {@code PATIENT_NOT_FOUND}). */
  String errorCode();

  /** Status HTTP con el que se responde. */
  HttpStatus status();
}
