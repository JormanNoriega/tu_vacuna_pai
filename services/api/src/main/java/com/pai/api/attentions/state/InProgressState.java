package com.pai.api.attentions.state;

import com.pai.api.attentions.entity.AttentionEntity;
import java.time.Instant;

/**
 * Estado intermedio (En Progreso).
 *
 * <p>La atencion cuenta con dosis aplicadas o actividad clinica abierta.
 * Permite seguir registrando dosis, actualizar observaciones y completar
 * o anular la atencion.
 */
public final class InProgressState implements AttentionState {

  public static final InProgressState INSTANCE = new InProgressState();

  private InProgressState() {}

  @Override
  public AttentionEntity.Status getStatus() {
    return AttentionEntity.Status.IN_PROGRESS;
  }

  @Override
  public boolean isEditable() {
    return true;
  }

  @Override
  public boolean acceptsDoses() {
    return true;
  }

  @Override
  public void onRegisterDose(AttentionEntity attention, Instant now) {
    // Ya esta en progreso: acepta dosis adicionales sin cambio de estado
  }

  @Override
  public void onUpdate(AttentionEntity attention, Instant now) {
    // Permitido en progreso
  }

  @Override
  public void onComplete(AttentionEntity attention, Instant now) {
    attention.transitionTo(AttentionEntity.Status.COMPLETED, now);
  }

  @Override
  public void onCancel(AttentionEntity attention, Instant now) {
    attention.transitionTo(AttentionEntity.Status.CANCELLED, now);
  }
}

