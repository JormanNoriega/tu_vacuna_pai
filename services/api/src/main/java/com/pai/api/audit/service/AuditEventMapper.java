package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;
import com.pai.api.audit.entity.AuditEventEntity;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Mapeo {@link AuditRecord} {@literal ->} {@link AuditEventEntity} (SRP). Genera
 * la identidad y la marca temporal del evento para que el servicio de auditoria
 * solo orqueste persistencia y serializacion.
 */
@Component
public class AuditEventMapper {

  public AuditEventEntity toEntity(AuditRecord record, String payloadJson) {
    return new AuditEventEntity(
        UUID.randomUUID(),
        record.actorId(),
        record.institutionId(),
        record.action().name(),
        record.resourceType().name(),
        record.resourceId(),
        record.clientOperationId(),
        payloadJson,
        Instant.now());
  }
}
