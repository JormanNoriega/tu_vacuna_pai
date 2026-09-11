package com.pai.api.audit.service;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.entity.AuditEventEntity;
import com.pai.api.audit.repository.AuditEventRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

/**
 * Registro de auditoria de operaciones sensibles. Se invoca dentro de la misma
 * transaccion que la operacion de negocio, de modo que un fallo de la operacion
 * revierte tambien su evento.
 */
@Service
public class AuditService {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final AuditEventRepository repository;

    public AuditService(AuditEventRepository repository) {
        this.repository = repository;
    }

    /**
     * Registra un evento de auditoria. {@code payload} es cualquier valor
     * serializable a JSON (DTO, mapa o record).
     */
    public void record(
            UUID actorId,
            UUID institutionId,
            AuditAction action,
            String resourceType,
            UUID resourceId,
            UUID clientOperationId,
            Object payload) {
        repository.save(new AuditEventEntity(
                UUID.randomUUID(),
                actorId,
                institutionId,
                action.name(),
                resourceType,
                resourceId,
                clientOperationId,
                toJson(payload),
                Instant.now()));
    }

    private String toJson(Object payload) {
        try {
            return MAPPER.writeValueAsString(payload);
        } catch (Exception ex) {
            // No debe romper la operacion de negocio por un fallo de auditoria.
            return "{}";
        }
    }
}
