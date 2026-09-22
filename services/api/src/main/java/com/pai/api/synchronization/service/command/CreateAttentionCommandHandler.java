package com.pai.api.synchronization.service.command;

import com.pai.api.attentions.dto.CreateAttentionRequest;
import com.pai.api.attentions.service.AttentionService;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Aplica {@code CREATE_ATTENTION} delegando en {@link AttentionService}. */
@Component
public class CreateAttentionCommandHandler implements SyncCommandHandler {

  public static final String COMMAND = "CREATE_ATTENTION";

  private final AttentionService attentions;
  private final SyncPayloadConverter payload;

  public CreateAttentionCommandHandler(AttentionService attentions, SyncPayloadConverter payload) {
    this.attentions = attentions;
    this.payload = payload;
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
    attentions.create(
        actorId,
        operationId,
        operation.aggregateId(),
        payload.convert(operation, CreateAttentionRequest.class));
  }
}
