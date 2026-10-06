package com.pai.api.synchronization.service.command;

import com.pai.api.attentions.dto.RegisterDoseRequest;
import com.pai.api.shared.json.JsonSerializer;
import com.pai.api.shared.util.Strings;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Convierte el {@code payload} de un {@link SyncOperation} al DTO del servicio
 * de dominio correspondiente (SRP): los handlers no conocen los detalles de
 * conversion.
 */
@Component
public class SyncPayloadConverter {

  private final JsonSerializer json;

  public SyncPayloadConverter(JsonSerializer json) {
    this.json = json;
  }

  /** Convierte el payload al tipo destino. */
  public <T> T convert(SyncOperation operation, Class<T> type) {
    return json.convert(Strings.safe(operation.payload()), type);
  }

  /** Convierte el payload de una dosis (sin {@code attentionId}, que no es del DTO). */
  public RegisterDoseRequest convertDose(SyncOperation operation) {
    Map<String, Object> payload = new HashMap<>(Strings.safe(operation.payload()));
    payload.remove("attentionId");
    return json.convert(payload, RegisterDoseRequest.class);
  }

  /** Extrae el {@code attentionId} del payload de la dosis. */
  public UUID attentionId(SyncOperation operation) {
    Object value = Strings.safe(operation.payload()).get("attentionId");
    if (value == null) {
      throw new IllegalArgumentException("El payload de la dosis requiere attentionId.");
    }
    try {
      return UUID.fromString(value.toString());
    } catch (IllegalArgumentException ex) {
      throw new IllegalArgumentException("attentionId invalido.");
    }
  }
}
