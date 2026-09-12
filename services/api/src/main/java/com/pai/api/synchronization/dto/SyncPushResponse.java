package com.pai.api.synchronization.dto;

import java.util.List;
import java.util.UUID;

/**
 * Resultado del push: {@code accepted} contiene los {@code operation_id}
 * aplicados (o rejugados por idempotencia) y {@code rejected} los que no se
 * pudieron aplicar, con su motivo.
 */
public record SyncPushResponse(List<UUID> accepted, List<RejectedOperation> rejected) {}
