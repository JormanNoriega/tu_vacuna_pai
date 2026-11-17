package com.pai.api.attentions.state;

public final class DraftState implements AttentionState {
  public static final DraftState INSTANCE = new DraftState();
  private DraftState() {}
  public String code() { return "DRAFT"; }
  public boolean isEditable() { return true; }
  public AttentionState complete() { return CompletedState.INSTANCE; }
  public AttentionState cancel() { return CancelledState.INSTANCE; }
}
