package com.pai.api.identity.service;

/**
 * Nombres canonicos de permisos del modulo de identidad. Centraliza los
 * literales que antes se repetian en {@link DataScope},
 * {@link UserProvisioningService} y en las anotaciones
 * {@code @PreAuthorize} de {@code AdminController} (DRY).
 */
public final class IdentityPermissions {

    private IdentityPermissions() {}

    /** Permiso de gestion global de instituciones y usuarios. */
    public static final String INSTITUTION_WRITE = "INSTITUTION_WRITE";

    /** Permiso de gestion de usuarios de la propia institucion. */
    public static final String USER_MANAGE = "USER_MANAGE";
}