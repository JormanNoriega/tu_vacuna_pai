package com.pai.api.shared.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationServiceException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.exceptions.UserNotActiveException;

class ActiveUserAuthenticationConverterTest {

    @Test
    void convert_buildsAuthenticationWithResolvedPermissions() {
        UUID userId = UUID.randomUUID();
        IdentityService identityService = mock(IdentityService.class);
        InstitutionEntity institution = new InstitutionEntity(UUID.randomUUID(), "INST-1",
            "Institucion 1", InstitutionEntity.Status.ACTIVE, (short) 72,
            Instant.now(), Instant.now());

        when(identityService.resolve(userId)).thenReturn(new AuthorizedUser(
            userId, "vacunador@test.com", "Ana Vacunadora", institution,
            List.of("VACCINATOR"), List.of("PATIENT_READ", "ATTENTION_CREATE"),
            Instant.now()));

        ActiveUserAuthenticationConverter converter =
            new ActiveUserAuthenticationConverter(identityService);

        var jwt = org.springframework.security.oauth2.jwt.Jwt.withTokenValue("token")
            .header("alg", "RS256")
            .subject(userId.toString())
            .claim("scope", "openid")
            .build();

        UsernamePasswordAuthenticationToken auth = converter.convert(jwt);

        assertThat(auth.getPrincipal()).isInstanceOf(AuthorizedUser.class);
        AuthorizedUser principal = (AuthorizedUser) auth.getPrincipal();
        assertThat(principal.getId()).isEqualTo(userId);
        // El access token viaja en el principal porque Spring Security borra las
        // credenciales del Authentication despues de autenticar.
        assertThat(principal.getAccessToken()).isEqualTo("token");
        assertThat(auth.getAuthorities())
            .extracting(a -> a.getAuthority())
            .contains("PERMISSION_PATIENT_READ", "PERMISSION_ATTENTION_CREATE");
    }

    @Test
    void convert_translatesInactiveUserIntoAuthenticationFailure() {
        UUID userId = UUID.randomUUID();
        IdentityService identityService = mock(IdentityService.class);
        when(identityService.resolve(userId))
            .thenThrow(new UserNotActiveException("El usuario esta desactivado."));

        ActiveUserAuthenticationConverter converter =
            new ActiveUserAuthenticationConverter(identityService);

        var jwt = org.springframework.security.oauth2.jwt.Jwt.withTokenValue("token")
            .header("alg", "RS256")
            .subject(userId.toString())
            .build();

        assertThatThrownBy(() -> converter.convert(jwt))
            .isInstanceOf(AuthenticationServiceException.class)
            .hasMessageContaining("desactivado");
    }
}