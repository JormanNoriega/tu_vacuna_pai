package com.pai.api.identity.service;

import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Componente Adaptable (Adaptee) del patron estructural Adapter.
 *
 * <p>Encapsula las llamadas HTTP de bajo nivel y los endpoints crudos de las
 * Edge Functions de Supabase (protocolo de transporte REST, headers JWT y
 * payloads JSON genéricos {@code Map<String, Object>}). Desacoplado de las reglas
 * de negocio y de las excepciones de dominio del sistema PAI.
 */
@Component
public class SupabaseAuthRestClient {

  private final RestClient restClient;
  private final String baseUrl;

  public SupabaseAuthRestClient(
      @Value("${app.auth-functions-url}") String baseUrl, RestClient.Builder restClientBuilder) {
    this.baseUrl = baseUrl;
    this.restClient = restClientBuilder.build();
  }

  /**
   * Ejecuta la peticion HTTP POST cruda contra la Edge Function de creacion.
   */
  public ResponseEntity<Map> postCreateAuthUser(String accessToken, Map<String, Object> payload) {
    return restClient
        .post()
        .uri(baseUrl + "/create-auth-user")
        .header("Authorization", "Bearer " + accessToken)
        .body(payload)
        .retrieve()
        .toEntity(Map.class);
  }

  /**
   * Ejecuta la peticion HTTP DELETE cruda contra la Edge Function de eliminacion.
   */
  public void deleteAuthUser(String accessToken, UUID userId) {
    restClient
        .delete()
        .uri(baseUrl + "/delete-auth-user/{id}", userId)
        .header("Authorization", "Bearer " + accessToken)
        .retrieve()
        .toBodilessEntity();
  }
}
