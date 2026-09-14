package com.pai.api.shared.security;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Guardia unica de autorizacion por permiso. Resuelve el actor y verifica que
 * posea el permiso solicitado.
 *
 * <p>Centraliza una responsabilidad que se repetia en cada servicio
 * (SRP): {@code VaccineService} e {@code InstitutionVaccineService} implementaban
 * el mismo metodo privado {@code actor(actorId, permission)}.
 */
@Service
public class PermissionGuard {

    private final IdentityService identity;

    public PermissionGuard(IdentityService identity) {
        this.identity = identity;
    }

    /**
     * Resuelve el actor y lanza {@link PermissionDeniedException} si no tiene
     * el permiso {@code permission}.
     */
    public AuthorizedUser require(UUID actorId, String permission) {
        AuthorizedUser actor = identity.resolve(actorId);
        if (!actor.getPermissions().contains(permission)) {
            throw new PermissionDeniedException("Permiso insuficiente: " + permission);
        }
        return actor;
    }
}