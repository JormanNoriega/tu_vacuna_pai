package com.pai.api.shared.exceptions;

/**
 * La operacion de aprovisionamiento sigue pendiente o en curso (p. ej. una
 * compensacion fallida o un reintento mientras otro request avanza la misma
 * operacion). El cliente debe reintentar o revisar la reconciliacion; nunca se
 * interpreta como un duplicado de correo.
 */
public class ProvisioningPendingException extends RuntimeException {

    public ProvisioningPendingException(String message) {
        super(message);
    }
}
