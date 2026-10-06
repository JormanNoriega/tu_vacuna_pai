package com.pai.api.shared.application;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.AuditRecord;
import com.pai.api.audit.AuditResourceType;
import com.pai.api.audit.service.AuditRecorder;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;
import org.springframework.stereotype.Component;

/**
 * Coordinador de escrituras de negocio que aplican idempotencia por
 * {@code operationId} (D3) y registran auditoria en la misma transaccion.
 *
 * <p>Aplica el principio abierto/cerrado (OCP): un servicio de negocio solo
 * aporta el cuerpo de la operacion (dominio) y el coordinador se encarga de la
 * ceremonia transversal {@code find -> ejecutar -> auditar -> registrar}. Agregar
 * una operacion nueva no exige tocar codigo existente del coordinador.
 */
@Component
public class IdempotencyCoordinator {

  private final AuditRecorder audit;
  private final ProcessedOperationsPort processedOperations;

  public IdempotencyCoordinator(AuditRecorder audit, ProcessedOperationsPort processedOperations) {
    this.audit = audit;
    this.processedOperations = processedOperations;
  }

  /**
   * Resultado de un cuerpo de escritura: el agregado afectado y la respuesta.
   */
  public record WriteResult<T>(UUID aggregateId, T response) {}

  /**
   * Datos de auditoria de la escritura. Se construyen de forma diferida
   * ({@code Supplier}) para que en una repeticion idempotente no se resuelva
   * siquiera el actor: el replay no ejecuta absolutamente nada.
   */
  public record AuditContext(
      UUID actorId, UUID institutionId, AuditAction action, AuditResourceType resourceType) {}

  /**
   * Ejecuta una escritura idempotente. Si {@code operationId} ya fue
   * procesado, repite la respuesta guardada sin ejecutar el cuerpo ni
   * construir el {@code context} de auditoria.
   */
  public <T> T execute(
      String operationId,
      String commandType,
      Class<T> responseType,
      Supplier<AuditContext> context,
      Supplier<Object> payload,
      Supplier<WriteResult<T>> body) {
    var previous = processedOperations.find(operationId, responseType);
    if (previous.isPresent()) {
      return previous.get();
    }
    WriteResult<T> result = body.get();
    AuditContext auditContext = context.get();
    audit.record(new AuditRecord(
        auditContext.actorId(),
        auditContext.institutionId(),
        auditContext.action(),
        auditContext.resourceType(),
        result.aggregateId(),
        parseOperationId(operationId),
        result.response()));
    processedOperations.record(
        operationId,
        commandType,
        result.aggregateId(),
        auditContext.institutionId(),
        payload.get(),
        result.response());
    return result.response();
  }

  /**
   * Ejecuta una escritura sin idempotencia (actualizaciones de recursos ya
   * existentes) y registra auditoria con el propio response como payload.
   * {@code clientOperationId} es nulo.
   */
  public <T> T executeAudited(
      UUID actorId,
      UUID institutionId,
      AuditAction action,
      AuditResourceType resourceType,
      UUID aggregateId,
      Supplier<T> body) {
    return executeAudited(
        actorId, institutionId, action, resourceType, aggregateId, response -> response, body);
  }

  /**
   * Variante con payload de auditoria propio (p. ej. cancelaciones, donde el
   * payload es {@code {resource, reason}} en lugar del response). El
   * {@code payload} se evalua despues del cuerpo para capturar el estado final.
   */
  public <T> T executeAudited(
      UUID actorId,
      UUID institutionId,
      AuditAction action,
      AuditResourceType resourceType,
      UUID aggregateId,
      Function<T, Object> payload,
      Supplier<T> body) {
    T response = body.get();
    audit.record(new AuditRecord(
        actorId, institutionId, action, resourceType, aggregateId, null, payload.apply(response)));
    return response;
  }

  /** Parsea el {@code operationId} de cliente a UUID, o {@code null} si no es valido. */
  public UUID parseOperationId(String operationId) {
    if (operationId == null || operationId.isBlank()) {
      return null;
    }
    try {
      return UUID.fromString(operationId.trim());
    } catch (IllegalArgumentException ex) {
      return null;
    }
  }
}
