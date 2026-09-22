package com.pai.api.shared.exceptions;

/** Cuerpo de error uniforme de la API: codigo estable + mensaje. */
public record ErrorResponse(String error, String message) {}
