package com.pai.api.audit;

import java.util.UUID;

/**
 * Datos de un evento de auditoria (command object). Sustituye la firma
 * posicional de siete parametros por un unico contrato entre los emisores y el
 * {@link com.pai.api.audit.service.AuditRecorder}, de modo que agregar un campo
 * no obligue a tocar cada llamada.
 */
public record AuditRecord(
    UUID actorId,
    UUID institutionId,
    AuditAction action,
    AuditResourceType resourceType,
    UUID resourceId,
    UUID clientOperationId,
    Object payload) {}
