package com.pai.api.synchronization.service.command;

import com.pai.api.attentions.service.AttentionService;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Aplica {@code REGISTER_APPLIED_DOSE} delegando en {@link AttentionService}. */
@Component
public class RegisterDoseCommandHandler implements SyncCommandHandler {

  public static final String COMMAND = "REGISTER_APPLIED_DOSE";

  private final AttentionService attentions;
  private final SyncPayloadConverter payload;

  public RegisterDoseCommandHandler(AttentionService attentions, SyncPayloadConverter payload) {
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
    attentions.registerDose(
        actorId,
        operationId,
        payload.attentionId(operation),
        operation.aggregateId(),
        payload.convertDose(operation));
  }
}
