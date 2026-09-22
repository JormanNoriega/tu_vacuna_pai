package com.pai.api.attentions.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import org.springframework.http.HttpStatus;

/**
 * Seleccion de catalogo invalida al registrar una dosis: la vacuna no esta
 * activa o no esta habilitada en la institucion. La declara el puerto
 * {@code VaccineCatalogPolicy} (modulo clinico) y la lanza su implementacion en
 * el modulo {@code catalog}; mapea a {@code 409 INVALID_CATALOG_SELECTION}.
 */
public class InvalidCatalogSelectionException extends DomainRuntimeException {

  public InvalidCatalogSelectionException(String message) {
    super(message);
  }

  @Override
  public String errorCode() {
    return "INVALID_CATALOG_SELECTION";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
