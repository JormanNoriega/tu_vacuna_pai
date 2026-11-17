package com.pai.api.attentions.entity;

import com.pai.api.attentions.state.AttentionState;
import com.pai.api.attentions.state.CancelledState;
import com.pai.api.attentions.state.CompletedState;
import com.pai.api.attentions.state.DraftState;
import com.pai.api.attentions.state.InProgressState;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/** Traduce el estado del dominio al contrato estable de la columna status. */
@Converter
public class AttentionStateConverter implements AttributeConverter<AttentionState, String> {
  @Override
  public String convertToDatabaseColumn(AttentionState state) {
    if (state == null) throw new IllegalArgumentException("El estado de la atencion es obligatorio.");
    return state.code();
  }

  @Override
  public AttentionState convertToEntityAttribute(String code) {
    if (code == null) throw new IllegalArgumentException("El estado de la atencion es obligatorio.");
    return switch (code) {
      case "DRAFT" -> DraftState.INSTANCE;
      case "IN_PROGRESS" -> InProgressState.INSTANCE;
      case "COMPLETED" -> CompletedState.INSTANCE;
      case "CANCELLED" -> CancelledState.INSTANCE;
      default -> throw new IllegalArgumentException("Estado de atencion desconocido: " + code);
    };
  }
}
