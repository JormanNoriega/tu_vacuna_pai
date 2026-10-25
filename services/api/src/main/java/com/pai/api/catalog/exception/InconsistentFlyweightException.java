package com.pai.api.catalog.exception;

/**
 * Excepcion lanzada cuando se intenta registrar o solicitar una vacuna
 * con un codigo existente pero con atributos intrinsecos inconsistentes.
 */
public class InconsistentFlyweightException extends IllegalArgumentException {

  public InconsistentFlyweightException(String message) {
    super(message);
  }
}
