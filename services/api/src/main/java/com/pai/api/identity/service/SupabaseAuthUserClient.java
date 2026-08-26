package com.pai.api.identity.service;

import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import com.pai.api.shared.exceptions.EmailAlreadyExistsException;

/**
 * Implementacion HTTP del aprovisionamiento contra las Edge Functions de
 * Supabase. La URL se configura con la propiedad {@code app.auth-functions-url}.
 *
 * <p>La contrasena temporal se envia en el cuerpo del request y nunca se
 * registra en logs ni se devuelve en la respuesta.
 */
@Component
public class SupabaseAuthUserClient implements AuthUserProvisioningClient {

    private final RestClient restClient;
    private final String baseUrl;

    public SupabaseAuthUserClient(
            @Value("${app.auth-functions-url:https://jfxkrznzhfvecaaixkjv.supabase.co/functions/v1}") String baseUrl,
            RestClient.Builder restClientBuilder) {
        this.baseUrl = baseUrl;
        this.restClient = restClientBuilder.build();
    }

    @Override
    public UUID createAuthUser(String accessToken, String email, String password, String fullName) {
        Map<String, Object> body = Map.of(
            "email", email,
            "password", password,
            "fullName", fullName);

        var response = restClient.post()
            .uri(baseUrl + "/create-auth-user")
            .header("Authorization", "Bearer " + accessToken)
            .body(body)
            .retrieve()
            .onStatus(status -> status == HttpStatus.CONFLICT, (req, res) -> {
                throw new EmailAlreadyExistsException(
                    "Ya existe un usuario con ese correo.");
            })
            .toEntity(Map.class);

        Object rawId = response.getBody() == null ? null : response.getBody().get("id");
        if (rawId == null) {
            throw new IllegalStateException(
                "La Edge Function no devolvio el id del usuario creado.");
        }
        return UUID.fromString(rawId.toString());
    }

    @Override
    public void deleteAuthUser(String accessToken, UUID userId) {
        restClient.delete()
            .uri(baseUrl + "/delete-auth-user/{id}", userId)
            .header("Authorization", "Bearer " + accessToken)
            .retrieve()
            .toBodilessEntity();
    }
}
