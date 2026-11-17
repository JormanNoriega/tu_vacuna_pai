package com.pai.api.attentions.state;

/** Comportamiento del ciclo de vida de una atencion. Los estados son inmutables. */
public interface AttentionState {
  String code();
  boolean isEditable();
  AttentionState complete();
  AttentionState cancel();

  default boolean acceptsDoses() {
    return isEditable();
  }
}
