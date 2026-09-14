package com.pai.api.attentions.exception;

/** La dosis aplicada no existe dentro de la atencion indicada. */
public class DoseNotFoundException extends RuntimeException {

  public DoseNotFoundException(String message) {
    super(message);
  }
}
