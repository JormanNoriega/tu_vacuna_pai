package com.pai.api.synchronization.dto;

import java.util.UUID;

/** Operacion rechazada con su motivo contractual. */
public record RejectedOperation(UUID operationId, String reason, String error) {}
