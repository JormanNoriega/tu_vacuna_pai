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
    private final String accessToken;

    public AuthorizedUser(
            UUID id,
            String email,
            String fullName,
            InstitutionEntity institution,
            List<String> roles,
            List<String> permissions,
            Instant lastOnlineValidation) {
        this(id, email, fullName, institution, roles, permissions,
            lastOnlineValidation, null);
    }

    public AuthorizedUser(
            UUID id,
            String email,
            String fullName,
            InstitutionEntity institution,
            List<String> roles,
            List<String> permissions,
            Instant lastOnlineValidation,
            String accessToken) {
        this.id = id;
        this.email = email;
        this.fullName = fullName;
        this.institution = institution;
        this.roles = roles;
        this.permissions = permissions;
        this.lastOnlineValidation = lastOnlineValidation;
        this.accessToken = accessToken;
    }

    /**
     * Copia de este perfil con el access token del JWT vigente. Spring Security
     * borra las credenciales del {@code Authentication} tras autenticar, asi que
     * el token se transporta en el principal para poder reenviarlo a las Edge
     * Functions (el cliente nunca lo envia en el body).
     */
    public AuthorizedUser withAccessToken(String accessToken) {
        return new AuthorizedUser(
            id, email, fullName, institution, roles, permissions,
            lastOnlineValidation, accessToken);
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

    /**
     * Access token del JWT actual. Puede ser null cuando el perfil se resuelve
     * fuera del ciclo de una peticion (p. ej. {@code GET /me} no lo necesita).
     */
    public String getAccessToken() {
        return accessToken;
    }
}