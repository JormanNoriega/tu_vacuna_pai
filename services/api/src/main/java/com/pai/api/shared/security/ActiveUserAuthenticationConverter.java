package com.pai.api.shared.security;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.exceptions.UserNotActiveException;
import com.pai.api.shared.exceptions.UserNotFoundException;
import java.util.UUID;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * Convierte un JWT de Supabase en un Authentication. La identidad proviene del
 * claim {@code sub}; los permisos y el perfil se resuelven en Spring desde la
 * base de datos (estado vigente), no desde los claims.
 */
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
      // El token viaja en el principal: Spring Security borra las
      // credenciales del Authentication tras autenticar, de modo que
      // getCredentials() no es fiable para transportar el JWT.
      authorizedUser = identityService.resolve(userId).withAccessToken(jwt.getTokenValue());
    } catch (UserNotFoundException | UserNotActiveException ex) {
      throw new org.springframework.security.authentication.AuthenticationServiceException(
          ex.getMessage(), ex);
    }

    var authorities = authorizedUser.getPermissions().stream()
        .map(permission -> new SimpleGrantedAuthority("PERMISSION_" + permission))
        .toList();

    return new UsernamePasswordAuthenticationToken(authorizedUser, jwt, authorities);
  }
}
