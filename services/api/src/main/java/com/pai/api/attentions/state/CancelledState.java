package com.pai.api.attentions.state;

import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import java.time.Instant;

/**
 * Estado final nulo (Anulada).
 *
 * <p>La atencion ha sido cancelada y no admite registro de dosis,
 * modificaciones ni cierres adicionales. Intentar anularla nuevamente
 * es rechazado por inconsistencia.
 */
public final class CancelledState implements AttentionState {

  public static final CancelledState INSTANCE = new CancelledState();

  private CancelledState() {}

  @Override
  public AttentionEntity.Status getStatus() {
    return AttentionEntity.Status.CANCELLED;
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
        "La atencion no se puede modificar en su estado actual (CANCELLED).");
  }

  @Override
  public void onComplete(AttentionEntity attention, Instant now) {
    throw new InvalidClinicalStateException(
        "No se puede completar una atencion anulada.");
  }

  @Override
  public void onCancel(AttentionEntity attention, Instant now) {
    throw new InvalidClinicalStateException("La atencion ya esta anulada.");
  }
}
