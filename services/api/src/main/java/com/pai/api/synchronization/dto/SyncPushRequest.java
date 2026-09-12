package com.pai.api.synchronization.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/** Batch de operaciones del outbox del cliente. */
public record SyncPushRequest(
        @NotNull(message = "El batch de operaciones es obligatorio.")
        @Valid List<SyncOperation> operations) {}
