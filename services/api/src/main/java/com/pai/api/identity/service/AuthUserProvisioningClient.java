package com.pai.api.identity.service;

import java.util.UUID;

/**
 * Cliente del aprovisionamiento de identidad en Supabase Auth (Edge Functions).
 *
 * <p>Estas operaciones son invocadas con el access token del {@code SUPER_ADMIN}
 * autenticado; la Edge Function valida el JWT y el rol en la base de datos
 * antes de actuar. El service role nunca llega a Spring ni a Flutter.
 */
public interface AuthUserProvisioningClient {

    /**
     * Crea un usuario en {@code auth.users} y devuelve su id.
     *
     * @throws EmailAlreadyExistsException si el correo ya esta registrado
     */
    UUID createAuthUser(String accessToken, String email, String password, String fullName);

    /**
     * Elimina un usuario de {@code auth.users} (compensacion cuando falla la
     * creacion del espejo en {@code app.users}).
     */
    void deleteAuthUser(String accessToken, UUID userId);
}
