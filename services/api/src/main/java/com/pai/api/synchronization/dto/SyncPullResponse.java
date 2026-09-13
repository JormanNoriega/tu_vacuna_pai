package com.pai.api.synchronization.dto;

import java.util.List;

/**
 * Operaciones del scope del actor no vistas por el cliente, mas el nuevo cursor
 * compuesto {@code "{sync_sequence}|{created_at_iso}"}.
 */
public record SyncPullResponse(List<SyncOperation> operations, String nextCursor) {}
