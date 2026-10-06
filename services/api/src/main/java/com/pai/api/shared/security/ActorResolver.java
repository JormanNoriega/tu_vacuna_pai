package com.pai.api.shared.security;

import com.pai.api.identity.service.AuthorizedUser;
import java.util.UUID;
import org.springframework.security.core.Authentication;

/**
 * Extrae el actor autenticado del {@link Authentication} de Spring Security.
 *
 * <p>Centraliza el casteo del principal (que Spring resuelve como
 * {@link AuthorizedUser} en cada request protegido) para que los controllers no
 * repitan la misma extraccion.
 */
public final class ActorResolver {

  private ActorResolver() {}

  /** Actor autenticado (estado vigente resuelto por Spring Security). */
  public static AuthorizedUser resolve(Authentication authentication) {
    return (AuthorizedUser) authentication.getPrincipal();
  }

  /** Id del actor autenticado. */
  public static UUID actorId(Authentication authentication) {
    return resolve(authentication).getId();
  }

  /**
   * Extrae el token Bearer del header {@code Authorization}. Falla si no esta
   * presente: los endpoints que reenvian el token a las Edge Functions lo
   * necesitan.
   */
  public static String bearerToken(String authorizationHeader) {
    if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
      throw new IllegalStateException("No se pudo recuperar el access token.");
    }
    return authorizationHeader.substring("Bearer ".length());
  }
}
