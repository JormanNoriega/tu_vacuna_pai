package com.pai.api.attentions.state;

import com.pai.api.attentions.entity.AttentionEntity;
import java.time.Instant;

/**
 * Contrato del patron GoF State para el ciclo de vida de {@link AttentionEntity}.
 *
 * <p>Encapsula las reglas clinicas y transiciones permitidas segun el estado
 * actual de la atencion, eliminando validaciones condicionales dispersas en
 * {@code AttentionService} y entidades de persistencia.
 */
public interface AttentionState {

  /** Estado del enum correspondiente. */
  AttentionEntity.Status getStatus();

  /** Indica si la atencion admite modificaciones en sus datos generales. */
  boolean isEditable();

  /** Indica si la atencion puede admitir nuevas dosis aplicadas. */
  boolean acceptsDoses();

  /**
   * Valida y ejecuta la transicion previa al registro de una dosis.
   * Si la atencion estaba en DRAFT, avanza a IN_PROGRESS.
   */
  void onRegisterDose(AttentionEntity attention, Instant now);

  /** Valida si se pueden actualizar los detalles de la atencion. */
  void onUpdate(AttentionEntity attention, Instant now);

  /** Valida y ejecuta el cierre de la atencion (COMPLETED). */
  void onComplete(AttentionEntity attention, Instant now);

  /** Valida y ejecuta la anulacion de la atencion (CANCELLED). */
  void onCancel(AttentionEntity attention, Instant now);
}

