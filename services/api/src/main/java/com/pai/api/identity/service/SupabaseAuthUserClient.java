package com.pai.api.identity.service;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import com.pai.api.shared.exceptions.AuthUserProvisioningException;
import com.pai.api.shared.exceptions.EmailAlreadyExistsException;
import com.pai.api.shared.exceptions.UncertainProvisioningException;

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
    public UUID createAuthUser(String accessToken, UUID operationId,
            String email, String password, String fullName, AuthUserProfile profile) {
        Map<String, Object> body = new HashMap<>();
        body.put("email", email);
        body.put("password", password);
        body.put("fullName", fullName);
        body.put("operationId", operationId);
        if (profile != null) {
            putIfPresent(body, "documentType", profile.documentType());
            putIfPresent(body, "documentNumber", profile.documentNumber());
            putIfPresent(body, "phone", profile.phone());
            putIfPresent(body, "birthDate",
                profile.birthDate() == null ? null : profile.birthDate().toString());
            putIfPresent(body, "gender", profile.gender());
            putIfPresent(body, "professionCode", profile.professionCode());
            putIfPresent(body, "professionalRegistrationNumber",
                profile.professionalRegistrationNumber());
            putIfPresent(body, "professionalRegistrationType",
                profile.professionalRegistrationType());
        }

        try {
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
                throw new UncertainProvisioningException(
                    "La Edge Function no devolvio el id del usuario creado.");
            }
            return UUID.fromString(rawId.toString());
        } catch (HttpStatusCodeException ex) {
            if (ex.getStatusCode().is5xxServerError()) {
                throw new UncertainProvisioningException(
                    "No se pudo confirmar la creacion del usuario.", ex);
            }
            throw new AuthUserProvisioningException(
                "El servicio de identidad rechazo la creacion del usuario.", ex);
        } catch (ResourceAccessException ex) {
            throw new UncertainProvisioningException(
                "Sin respuesta del servicio de identidad.", ex);
        }
    }

    @Override
    public void deleteAuthUser(String accessToken, UUID userId) {
        restClient.delete()
            .uri(baseUrl + "/delete-auth-user/{id}", userId)
            .header("Authorization", "Bearer " + accessToken)
            .retrieve()
            .toBodilessEntity();
    }

    private static void putIfPresent(Map<String, Object> body, String key, String value) {
        if (value != null && !value.isBlank()) {
            body.put(key, value);
        }
    }
}
