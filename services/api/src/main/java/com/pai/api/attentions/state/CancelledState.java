package com.pai.api.attentions.state;

import com.pai.api.attentions.exception.InvalidClinicalStateException;

public final class CancelledState implements AttentionState {
  public static final CancelledState INSTANCE = new CancelledState();
  private CancelledState() {}
  public String code() { return "CANCELLED"; }
  public boolean isEditable() { return false; }
  public AttentionState complete() {
    throw new InvalidClinicalStateException("La atencion no se puede modificar en su estado actual.");
  }
  public AttentionState cancel() {
    throw new InvalidClinicalStateException("La atencion ya esta anulada.");
  }
}
