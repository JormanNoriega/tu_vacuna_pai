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
     * <p>El {@code operationId} se escribe en el {@code app_metadata} del
     * usuario en la misma llamada, para que la correlacion exista aunque la
     * respuesta HTTP se pierda. El perfil ampliado (documento, contacto,
     * registro profesional) viaja en el {@code user_metadata}; puede ser
     * {@code null} para perfiles sin campos extra (p. ej. administradores).
     *
     * @throws EmailAlreadyExistsException si el correo ya esta registrado
     * @throws AuthUserProvisioningException si el servicio rechaza la creacion
     *         (4xx distinto de 409): nada se creo
     * @throws UncertainProvisioningException si el resultado es incierto
     *         (timeout, 5xx o sin id): el usuario puede existir
     */
    UUID createAuthUser(
            String accessToken,
            UUID operationId,
            String email,
            String password,
            String fullName,
            AuthUserProfile profile);

    /**
     * Elimina un usuario de {@code auth.users} (compensacion cuando falla la
     * creacion del espejo en {@code app.users}). Idempotente: si el usuario ya
     * no existe se trata como exito.
     */
    void deleteAuthUser(String accessToken, UUID userId);
}
