package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;

/**
 * Decorador Base (Decorator) del patron estructural Decorator para el puerto de auditoria.
 *
 * <p>Mantiene una referencia al componente envuelto ({@link AuditRecorder}) y
 * conforma la misma interfaz, delegando la ejecucion basica. Las subclases
 * (decoradores concretos) extienden o modifican el comportamiento antes o
 * despues de delegar la grabacion del evento.
 */
public abstract class AuditRecorderDecorator implements AuditRecorder {

  protected final AuditRecorder delegate;

  protected AuditRecorderDecorator(AuditRecorder delegate) {
    this.delegate = delegate;
  }

  @Override
  public void record(AuditRecord record) {
    delegate.record(record);
  }
}
