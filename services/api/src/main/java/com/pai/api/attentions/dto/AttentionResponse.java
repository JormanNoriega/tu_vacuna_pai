package com.pai.api.attentions.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Representacion completa de una atencion con sus dosis aplicadas. */
public record AttentionResponse(
        UUID id,
        UUID patientId,
        UUID professionalId,
        UUID institutionId,
        Instant attentionDate,
        Long consecutive,
        String status,
        String observations,
        long version,
        Instant createdAt,
        Instant updatedAt,
        List<AppliedDoseResponse> doses) {
}
