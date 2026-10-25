package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

/**
 * Decorador Concreto (ConcreteDecorator) del patron estructural Decorator.
 *
 * <p>Intercepta el evento de auditoria y enmascara campos sensibles
 * (credenciales, tokens de acceso o datos confidenciales) en el {@code payload}
 * antes de delegar la persistencia al {@link AuditService} subyacente.
 *
 * <p>Se anota con {@link Primary} para que los clientes del puerto
 * {@link AuditRecorder} (como {@code IdempotencyCoordinator}) reciban la cadena
 * decorada sin alterar su codigo consumidor.
 */
@Component
@Primary
public class MaskingAuditRecorderDecorator extends AuditRecorderDecorator {

  private static final Logger log = LoggerFactory.getLogger(MaskingAuditRecorderDecorator.class);

  private static final String MASKED_VALUE = "******";
  private static final Set<String> SENSITIVE_KEYS = Set.of(
      "password",
      "contrasena",
      "token",
      "accesstoken",
      "access_token",
      "refreshtoken",
      "refresh_token",
      "secret",
      "authorization");

  public MaskingAuditRecorderDecorator(@Qualifier("auditService") AuditRecorder delegate) {
    super(delegate);
  }

  @Override
  public void record(AuditRecord record) {
    AuditRecord sanitized = maskSensitiveData(record);
    log.debug("Evento de auditoria procesado por MaskingAuditRecorderDecorator para recurso {}", record.resourceType());
    delegate.record(sanitized);
  }

  private AuditRecord maskSensitiveData(AuditRecord record) {
    if (record == null || record.payload() == null) {
      return record;
    }

    if (record.payload() instanceof Map<?, ?> map) {
      Map<String, Object> sanitizedMap = new LinkedHashMap<>();
      for (Map.Entry<?, ?> entry : map.entrySet()) {
        String key = String.valueOf(entry.getKey());
        Object value = entry.getValue();

        if (isSensitiveKey(key)) {
          sanitizedMap.put(key, MASKED_VALUE);
        } else if (value instanceof Map<?, ?> nestedMap) {
          sanitizedMap.put(key, maskNestedMap(nestedMap));
        } else {
          sanitizedMap.put(key, value);
        }
      }
      return new AuditRecord(
          record.actorId(),
          record.institutionId(),
          record.action(),
          record.resourceType(),
          record.resourceId(),
          record.clientOperationId(),
          Collections.unmodifiableMap(sanitizedMap));
    }

    return record;
  }

  private Map<String, Object> maskNestedMap(Map<?, ?> map) {
    Map<String, Object> sanitized = new LinkedHashMap<>();
    for (Map.Entry<?, ?> entry : map.entrySet()) {
      String key = String.valueOf(entry.getKey());
      Object value = entry.getValue();
      if (isSensitiveKey(key)) {
        sanitized.put(key, MASKED_VALUE);
      } else if (value instanceof Map<?, ?> nested) {
        sanitized.put(key, maskNestedMap(nested));
      } else {
        sanitized.put(key, value);
      }
    }
    return sanitized;
  }

  private boolean isSensitiveKey(String key) {
    if (key == null) {
      return false;
    }
    String normalized = key.toLowerCase().replace("-", "").replace("_", "");
    return SENSITIVE_KEYS.contains(normalized);
  }
}
