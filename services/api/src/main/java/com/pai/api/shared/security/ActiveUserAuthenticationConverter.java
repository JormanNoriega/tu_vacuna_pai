package com.pai.api.shared.security;

import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.exceptions.UserNotActiveException;
import com.pai.api.shared.exceptions.UserNotFoundException;

/**
 * Convierte un JWT de Supabase en un Authentication. La identidad proviene del
 * claim {@code sub}; los permisos y el perfil se resuelven en Spring desde la
 * base de datos (estado vigente), no desde los claims.
 */
public class ActiveUserAuthenticationConverter
        implements Converter<Jwt, UsernamePasswordAuthenticationToken> {

    private final IdentityService identityService;
    private final JwtGrantedAuthoritiesConverter defaultConverter =
        new JwtGrantedAuthoritiesConverter();

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
            throw new org.springframework.security.authentication
                .AuthenticationServiceException(ex.getMessage(), ex);
        }

        var authorities = authorizedUser.getPermissions().stream()
            .map(permission -> new SimpleGrantedAuthority("PERMISSION_" + permission))
            .collect(Collectors.toList());

        authorities.addAll(defaultConverter.convert(jwt).stream()
            .map(GrantedAuthority::getAuthority)
            .map(SimpleGrantedAuthority::new)
            .toList());

        return new UsernamePasswordAuthenticationToken(
            authorizedUser, jwt, authorities);
    }
}