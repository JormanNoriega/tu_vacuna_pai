package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;

/**
 * Puerto de auditoria (DIP). Los servicios de negocio y
 * {@link com.pai.api.shared.application.IdempotencyCoordinator} dependen de esta
 * abstraccion y no de la implementacion de persistencia, de forma coherente con
 * los puertos {@code VaccineCatalogPolicy} y {@code PatientScopePolicy}.
 */
public interface AuditRecorder {

  /** Registra el evento dentro de la transaccion de negocio en curso. */
  void record(AuditRecord record);
}
