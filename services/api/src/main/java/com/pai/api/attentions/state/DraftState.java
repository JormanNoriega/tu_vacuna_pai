package com.pai.api.attentions.state;

import com.pai.api.attentions.entity.AttentionEntity;
import java.time.Instant;

/**
 * Estado inicial (Borrador).
 *
 * <p>Permite modificar datos, anular y completar directamente. Al registrar
 * su primera dosis aplicada, transiciona automaticamente a {@code IN_PROGRESS}.
 */
public final class DraftState implements AttentionState {

  public static final DraftState INSTANCE = new DraftState();

  private DraftState() {}

  @Override
  public AttentionEntity.Status getStatus() {
    return AttentionEntity.Status.DRAFT;
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
    // Primera dosis aplicada: la atencion avanza formalmente a EN CURSO
    attention.transitionTo(AttentionEntity.Status.IN_PROGRESS, now);
  }

  @Override
  public void onUpdate(AttentionEntity attention, Instant now) {
    // Permitido en borrador
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

