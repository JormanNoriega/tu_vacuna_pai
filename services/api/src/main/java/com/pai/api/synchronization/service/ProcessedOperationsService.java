package com.pai.api.synchronization.service;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.pai.api.synchronization.entity.ProcessedOperationEntity;
import com.pai.api.synchronization.repository.ProcessedOperationRepository;

import tools.jackson.databind.ObjectMapper;

/**
 * Idempotencia de comandos clinicos (D3). Permite que un reenvio con el mismo
 * {@code operation_id} devuelva la respuesta original sin reprocesar.
 *
 * <p>La tabla {@code processed_operations} es compartida por los REST directos
 * y por {@code /sync/push}. Aqui solo se usa para el camino REST directo; el
 * push reutiliza la misma infraestructura cuando se implemente el SyncEngine.
 */
@Service
public class ProcessedOperationsService {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final ProcessedOperationRepository repository;

    public ProcessedOperationsService(ProcessedOperationRepository repository) {
        this.repository = repository;
    }

    /**
     * Devuelve la respuesta original de una operacion ya procesada, si existe.
     * Un {@code operationId} nulo/vacio o no UUID se trata como operacion nueva.
     */
    public <T> Optional<T> find(String operationId, Class<T> type) {
        UUID id = parse(operationId);
        if (id == null) {
            return Optional.empty();
        }
        return repository.findById(id).map(entity -> deserialize(entity, type));
    }

    /**
     * Registra la respuesta de una operacion procesada. No hace nada si el
     * {@code operationId} es nulo, vacio o no UUID (camino sin idempotencia).
     */
    public void record(String operationId, String commandType, UUID aggregateId,
            Object response) {
        UUID id = parse(operationId);
        if (id == null) {
            return;
        }
        repository.save(new ProcessedOperationEntity(
            id, commandType, aggregateId, serialize(response), Instant.now()));
    }

    private UUID parse(String operationId) {
        if (operationId == null || operationId.isBlank()) {
            return null;
        }
        try {
            return UUID.fromString(operationId.trim());
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private String serialize(Object response) {
        try {
            return MAPPER.writeValueAsString(response);
        } catch (Exception ex) {
            return "{}";
        }
    }

    private <T> T deserialize(ProcessedOperationEntity entity, Class<T> type) {
        try {
            return MAPPER.readValue(entity.getResponsePayload(), type);
        } catch (Exception ex) {
            throw new IllegalStateException(
                "No se pudo reconstruir la respuesta idempotente.", ex);
        }
    }
}
