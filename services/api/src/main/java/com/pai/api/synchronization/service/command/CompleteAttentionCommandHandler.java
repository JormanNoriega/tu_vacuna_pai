package com.pai.api.synchronization.service.command;

import com.pai.api.attentions.service.AttentionService;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Aplica {@code COMPLETE_ATTENTION} delegando en {@link AttentionService}. */
@Component
public class CompleteAttentionCommandHandler implements SyncCommandHandler {

  public static final String COMMAND = "COMPLETE_ATTENTION";

  private final AttentionService attentions;

  public CompleteAttentionCommandHandler(AttentionService attentions) {
    this.attentions = attentions;
  }

  @Override
  public String commandType() {
    return COMMAND;
  }

  @Override
  public String permission() {
    return "ATTENTION_CREATE";
  }

  @Override
  public void apply(UUID actorId, String operationId, SyncOperation operation) {
    attentions.complete(actorId, operationId, operation.aggregateId());
  }
}
