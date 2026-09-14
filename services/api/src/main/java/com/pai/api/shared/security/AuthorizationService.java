package com.pai.api.shared.security;

import com.pai.api.identity.service.AuthorizedUser;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/**
 * Autorizacion de operaciones sensibles. Recibe el {@link Authentication} que
 * Spring Security ya resolvio desde la base de datos (estado vigente, no claims
 * del JWT) y verifica si el usuario autenticado posee el permiso requerido.
 *
 * <p>Se usa desde anotaciones {@code @PreAuthorize}. El actor nunca se toma del
 * body de la peticion: siempre proviene del principal autenticado.
 */
@Component("authorization")
public class AuthorizationService {

  public boolean hasPermission(Authentication authentication, String permission) {
    if (authentication == null || !(authentication.getPrincipal() instanceof AuthorizedUser user)) {
      return false;
    }
    return user.getPermissions().contains(permission);
  }
}
