package com.pai.api.shared.exceptions;

/**
 * Base de las excepciones de dominio. Implementa {@link DomainException} y
 * extiende {@link RuntimeException} para que {@code @ExceptionHandler} pueda
 * capturarla de forma polimorfica (un {@code @ExceptionHandler} exige un
 * subtipo de {@code Throwable}; la interfaz sola no basta).
 *
 * <p>No se usa un catch-all de {@code RuntimeException}: eso regresaria los 400
 * que Spring ya produce para errores de framework (p. ej. JSON malformado).
 */
public abstract class DomainRuntimeException extends RuntimeException implements DomainException {

  protected DomainRuntimeException(String message) {
    super(message);
  }

  protected DomainRuntimeException(String message, Throwable cause) {
    super(message, cause);
  }
}
