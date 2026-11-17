package com.pai.api.attentions.state;

public final class InProgressState implements AttentionState {
  public static final InProgressState INSTANCE = new InProgressState();
  private InProgressState() {}
  public String code() { return "IN_PROGRESS"; }
  public boolean isEditable() { return true; }
  public AttentionState complete() { return CompletedState.INSTANCE; }
  public AttentionState cancel() { return CancelledState.INSTANCE; }
}
