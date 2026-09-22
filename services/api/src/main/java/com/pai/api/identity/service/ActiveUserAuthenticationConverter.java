package com.pai.api.identity.service;

import com.pai.api.identity.exception.UserNotActiveException;
import com.pai.api.identity.exception.UserNotFoundException;
import java.util.UUID;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AuthenticationServiceException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

/**
 * Convierte un JWT de Supabase en un Authentication. La identidad proviene del
 * claim {@code sub}; los permisos y el perfil se resuelven en Spring desde la
 * base de datos (estado vigente), no desde los claims.
 *
 * <p>Vive en el modulo {@code identity} (es su preocupacion: resolver el actor
 * vigente); el filter chain de {@code shared.security} solo lo cablea.
 */
@Component
public class ActiveUserAuthenticationConverter
    implements Converter<Jwt, UsernamePasswordAuthenticationToken> {

  private final IdentityService identityService;

  public ActiveUserAuthenticationConverter(IdentityService identityService) {
    this.identityService = identityService;
  }

  @Override
  public UsernamePasswordAuthenticationToken convert(Jwt jwt) {
    UUID userId = UUID.fromString(jwt.getSubject());

    AuthorizedUser authorizedUser;
    try {
      authorizedUser = identityService.resolve(userId);
    } catch (UserNotFoundException | UserNotActiveException ex) {
      throw new AuthenticationServiceException(ex.getMessage(), ex);
    }

    var authorities = authorizedUser.getPermissions().stream()
        .map(permission -> new SimpleGrantedAuthority("PERMISSION_" + permission))
        .toList();

    return new UsernamePasswordAuthenticationToken(authorizedUser, jwt, authorities);
  }
}
