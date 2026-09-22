package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;
import com.pai.api.audit.repository.AuditEventRepository;
import com.pai.api.shared.json.JsonSerializer;
import org.springframework.stereotype.Service;

/**
 * Implementacion de {@link AuditRecorder}: persiste el evento de auditoria en la
 * misma transaccion que la operacion de negocio, de modo que un fallo de la
 * operacion revierte tambien su evento.
 *
 * <p>El payload se serializa con {@link JsonSerializer#writeOrEmpty(Object)}:
 * un fallo de serializacion no aborta la operacion de negocio.
 */
@Service
public class AuditService implements AuditRecorder {

  private final AuditEventRepository repository;
  private final AuditEventMapper mapper;
  private final JsonSerializer json;

  public AuditService(
      AuditEventRepository repository, AuditEventMapper mapper, JsonSerializer json) {
    this.repository = repository;
    this.mapper = mapper;
    this.json = json;
  }

  @Override
  public void record(AuditRecord record) {
    repository.save(mapper.toEntity(record, json.writeOrEmpty(record.payload())));
  }
}
