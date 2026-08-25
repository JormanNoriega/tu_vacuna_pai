package com.pai.api.identity.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.pai.api.identity.entity.InstitutionEntity;

/**
 * Resultado de autorizacion para un usuario autenticado, resuelto por Spring
 * desde la base de datos en cada request protegido. No es una instantanea del
 * JWT: es el estado vigente del usuario.
 */
public class AuthorizedUser {

    private final UUID id;
    private final String email;
    private final String fullName;
    private final InstitutionEntity institution;
    private final List<String> roles;
    private final List<String> permissions;
    private final Instant lastOnlineValidation;

    public AuthorizedUser(
            UUID id,
            String email,
            String fullName,
            InstitutionEntity institution,
            List<String> roles,
            List<String> permissions,
            Instant lastOnlineValidation) {
        this.id = id;
        this.email = email;
        this.fullName = fullName;
        this.institution = institution;
        this.roles = roles;
        this.permissions = permissions;
        this.lastOnlineValidation = lastOnlineValidation;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getFullName() {
        return fullName;
    }

    public InstitutionEntity getInstitution() {
        return institution;
    }

    public List<String> getRoles() {
        return roles;
    }

    public List<String> getPermissions() {
        return permissions;
    }

    public Instant getLastOnlineValidation() {
        return lastOnlineValidation;
    }
}