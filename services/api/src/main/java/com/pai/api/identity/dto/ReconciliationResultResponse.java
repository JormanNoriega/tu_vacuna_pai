package com.pai.api.identity.dto;

import java.util.UUID;

/**
 * Resultado de reconciliar un huerfano de aprovisionamiento (auth.user sin
 * espejo en app.users).
 */
public record ReconciliationResultResponse(
    UUID operationId, UUID authUserId, String email, Outcome outcome, String detail) {

  public enum Outcome {
    RECONCILED,
    ALREADY_RECONCILED,
    SKIPPED_WITHOUT_OPERATION,
    SKIPPED_EMAIL_MISMATCH,
    FAILED
  }
}
