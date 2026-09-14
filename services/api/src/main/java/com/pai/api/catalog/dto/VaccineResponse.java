package com.pai.api.catalog.dto;

import java.util.UUID;

public record VaccineResponse(
    UUID id,
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
    boolean active,
    long version) {}
