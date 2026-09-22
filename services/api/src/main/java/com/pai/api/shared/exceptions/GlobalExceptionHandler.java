package com.pai.api.shared.exceptions;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Traduce excepciones a respuestas de error uniformes.
 *
 * <p>Las excepciones de dominio se resuelven de forma polimorfica via
 * {@link DomainException} (OCP): agregar una excepcion de dominio no toca este
 * handler. Las de framework ({@code IllegalArgumentException},
 * {@code MethodArgumentNotValidException}) conservan su status especifico; el
 * resto las maneja Spring por defecto.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(DomainRuntimeException.class)
  public ResponseEntity<ErrorResponse> handleDomain(DomainRuntimeException ex) {
    return ResponseEntity.status(ex.status())
        .body(new ErrorResponse(ex.errorCode(), ex.getMessage()));
  }

  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<ErrorResponse> handleIllegalArgument(IllegalArgumentException ex) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(new ErrorResponse("BAD_REQUEST", ex.getMessage()));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
    String message = ex.getBindingResult().getFieldErrors().stream()
        .findFirst()
        .map(error -> error.getDefaultMessage())
        .orElse("Datos invalidos.");
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(new ErrorResponse("VALIDATION_ERROR", message));
  }
}
