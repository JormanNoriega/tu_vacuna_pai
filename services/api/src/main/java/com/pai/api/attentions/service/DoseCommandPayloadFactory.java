package com.pai.api.attentions.service;

import com.pai.api.attentions.dto.RegisterDoseRequest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

/**
 * Construye el {@code payload} del comando de dosis que viaja en el outbox y en
 * {@code /sync/pull}.
 *
 * <p>Extraido de {@link AttentionService} (SRP): la serializacion del comando es
 * una responsabilidad distinta de la orquestacion de la operacion de negocio.
 */
@Component
public class DoseCommandPayloadFactory {

  private final ObjectMapper objectMapper;

  public DoseCommandPayloadFactory(ObjectMapper objectMapper) {
    this.objectMapper = objectMapper;
  }

  /**
   * Payload del comando. Conserva {@code attentionId} (no forma parte del DTO
   * REST) para que {@code /sync/pull} reconstruya la operacion.
   */
  @SuppressWarnings("unchecked")
  public Map<String, Object> forDose(UUID attentionId, RegisterDoseRequest request) {
    Map<String, Object> payload =
        new LinkedHashMap<>(objectMapper.convertValue(request, Map.class));
    payload.put("attentionId", attentionId);
    return payload;
  }
}
