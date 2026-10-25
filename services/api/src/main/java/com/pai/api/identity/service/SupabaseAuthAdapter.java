package com.pai.api.identity.service;

import com.pai.api.identity.exception.AuthUserProvisioningException;
import com.pai.api.identity.exception.EmailAlreadyExistsException;
import com.pai.api.identity.exception.UncertainProvisioningException;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;

/**
 * Adaptador (Adapter) del patron estructural Adapter.
 *
 * <p>Adapta la interfaz tecnica de bajo nivel de Supabase Auth
 * ({@link SupabaseAuthRestClient}, Adaptee) al contrato de dominio esperado por
 * el sistema PAI ({@link AuthUserProvisioningClient}, Target).
 *
 * <p>Responsabilidades de adaptacion:
 * <ul>
 *   <li>Transforma objetos de dominio tipados ({@link AuthUserProfile},
 *       {@code operationId}, credenciales) a la estructura JSON esperada por
 *       las Edge Functions de Supabase.</li>
 *   <li>Traduce codigos de estado HTTP y fallos de transporte
 *       ({@link HttpStatusCodeException}, {@link ResourceAccessException}) a
 *       excepciones de negocio ({@link EmailAlreadyExistsException},
 *       {@link UncertainProvisioningException},
 *       {@link AuthUserProvisioningException}).</li>
 * </ul>
 */
@Component
@Primary
public class SupabaseAuthAdapter implements AuthUserProvisioningClient {

  private final SupabaseAuthRestClient restClient;

  public SupabaseAuthAdapter(SupabaseAuthRestClient restClient) {
    this.restClient = restClient;
  }

  @Override
  public UUID createAuthUser(
      String accessToken,
      UUID operationId,
      String email,
      String password,
      String fullName,
      AuthUserProfile profile) {
    Map<String, Object> body = new HashMap<>();
    body.put("email", email);
    body.put("password", password);
    body.put("fullName", fullName);
    body.put("operationId", operationId);
    if (profile != null) {
      putIfPresent(body, "documentType", profile.documentType());
      putIfPresent(body, "documentNumber", profile.documentNumber());
      putIfPresent(body, "phone", profile.phone());
      putIfPresent(
          body,
          "birthDate",
          profile.birthDate() == null ? null : profile.birthDate().toString());
      putIfPresent(body, "gender", profile.gender());
      putIfPresent(body, "professionCode", profile.professionCode());
      putIfPresent(
          body, "professionalRegistrationNumber", profile.professionalRegistrationNumber());
      putIfPresent(body, "professionalRegistrationType", profile.professionalRegistrationType());
    }

    try {
      var response = restClient.postCreateAuthUser(accessToken, body);
      Object rawId = response.getBody() == null ? null : response.getBody().get("id");
      if (rawId == null) {
        throw new UncertainProvisioningException(
            "La Edge Function no devolvio el id del usuario creado.");
      }
      return UUID.fromString(rawId.toString());
    } catch (HttpStatusCodeException ex) {
      if (ex.getStatusCode() == HttpStatus.CONFLICT) {
        throw new EmailAlreadyExistsException("Ya existe un usuario con ese correo.");
      }
      if (ex.getStatusCode().is5xxServerError()) {
        throw new UncertainProvisioningException(
            "No se pudo confirmar la creacion del usuario.", ex);
      }
      throw new AuthUserProvisioningException(
          "El servicio de identidad rechazo la creacion del usuario.", ex);
    } catch (ResourceAccessException ex) {
      throw new UncertainProvisioningException("Sin respuesta del servicio de identidad.", ex);
    }
  }

  @Override
  public void deleteAuthUser(String accessToken, UUID userId) {
    restClient.deleteAuthUser(accessToken, userId);
  }

  private static void putIfPresent(Map<String, Object> body, String key, String value) {
    if (value != null && !value.isBlank()) {
      body.put(key, value);
    }
  }
}
