package com.pai.api.attentions.state;

import com.pai.api.attentions.exception.InvalidClinicalStateException;

public final class CompletedState implements AttentionState {
  public static final CompletedState INSTANCE = new CompletedState();
  private CompletedState() {}
  public String code() { return "COMPLETED"; }
  public boolean isEditable() { return false; }
  public AttentionState complete() {
    throw new InvalidClinicalStateException("La atencion no se puede modificar en su estado actual.");
  }
  public AttentionState cancel() { return CancelledState.INSTANCE; }
}
