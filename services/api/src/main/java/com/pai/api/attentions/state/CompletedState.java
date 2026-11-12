package com.pai.api.attentions.state;

import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import java.time.Instant;

/**
 * Estado final inmutable (Completada).
 *
 * <p>El agregado clinico queda sellado e inmutable. No admite modificaciones
 * generales ni nuevas dosis. Solo admite anulacion con motivo explicito si el
 * negocio institucional lo requiere.
 */
public final class CompletedState implements AttentionState {

  public static final CompletedState INSTANCE = new CompletedState();

  private CompletedState() {}

  @Override
  public AttentionEntity.Status getStatus() {
    return AttentionEntity.Status.COMPLETED;
  }

  @Override
  public boolean isEditable() {
    return false;
  }

  @Override
  public boolean acceptsDoses() {
    return false;
  }

  @Override
  public void onRegisterDose(AttentionEntity attention, Instant now) {
    throw new InvalidClinicalStateException(
        "No se pueden registrar dosis en una atencion completada o anulada.");
  }

  @Override
  public void onUpdate(AttentionEntity attention, Instant now) {
    throw new InvalidClinicalStateException(
        "La atencion no se puede modificar en su estado actual (COMPLETED).");
  }

  @Override
  public void onComplete(AttentionEntity attention, Instant now) {
    throw new InvalidClinicalStateException(
        "La atencion no se puede modificar en su estado actual (COMPLETED).");
  }

  @Override
  public void onCancel(AttentionEntity attention, Instant now) {
    attention.transitionTo(AttentionEntity.Status.CANCELLED, now);
  }
}

