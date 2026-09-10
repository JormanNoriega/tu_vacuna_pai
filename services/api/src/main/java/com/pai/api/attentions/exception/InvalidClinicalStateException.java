package com.pai.api.attentions.exception;

/**
 * Transicion o mutacion invalida del agregado clinico (p. ej. editar una
 * atencion {@code COMPLETED}, registrar una dosis en una atencion anulada, o
 * cancelar una dosis ya cancelada). Mapea a {@code 409 INVALID_STATE}.
 */
public class InvalidClinicalStateException extends RuntimeException {

    public InvalidClinicalStateException(String message) {
        super(message);
    }
}
