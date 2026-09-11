package com.pai.api.attentions.dto;

import java.time.Instant;
import java.util.UUID;

/** Dosis aplicada con su snapshot de catalogo. */
public record AppliedDoseResponse(
        UUID id,
        UUID attentionId,
        UUID vaccineId,
        String vaccineNameSnapshot,
        String vaccineCodeSnapshot,
        UUID doseOptionId,
        String doseLabelSnapshot,
        String doseValueSnapshot,
        UUID pneumococcalTypeOptionId,
        String pneumococcalTypeSnapshot,
        UUID lotId,
        String lotNumber,
        Instant applicationDate,
        long catalogVersion,
        String selectedLaboratorySnapshot,
        String selectedSyringeSnapshot,
        String selectedDropperSnapshot,
        String selectedObservationSnapshot,
        String status,
        String cancelledReason,
        Instant cancelledAt,
        Instant createdAt) {}
