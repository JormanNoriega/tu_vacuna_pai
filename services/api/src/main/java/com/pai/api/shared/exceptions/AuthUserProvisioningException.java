package com.pai.api.shared.exceptions;

/**
 * Rechazo definitivo de la creacion del auth.user (4xx distinto de 409): nada
 * se creo y la operacion se marca {@code REJECTED}.
 */
public class AuthUserProvisioningException extends RuntimeException {

    public AuthUserProvisioningException(String message, Throwable cause) {
        super(message, cause);
    }
}
