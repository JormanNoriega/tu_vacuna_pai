package com.pai.api.catalog.dto;

import java.util.UUID;

public record InstitutionVaccineResponse(
    UUID id,
    UUID institutionId,
    UUID vaccineId,
    String name,
    String code,
    String category,
    short maxDoses,
    Integer minAgeMonths,
    Integer maxAgeMonths,
    boolean hasLaboratory,
    boolean hasLot,
    boolean hasSyringe,
    boolean hasSyringeLot,
    boolean hasDiluent,
    boolean hasDropper,
    boolean hasPneumococcalType,
    boolean hasVialCount,
    boolean hasObservation,
    boolean enabled,
    long version) {}
