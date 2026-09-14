package com.pai.api.attentions.exception;

/** La atencion no existe o esta fuera del alcance de la institucion del actor. */
public class AttentionNotFoundException extends RuntimeException {

  public AttentionNotFoundException(String message) {
    super(message);
  }
}
