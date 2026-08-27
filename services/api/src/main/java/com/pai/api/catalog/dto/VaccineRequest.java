package com.pai.api.catalog.dto;
import jakarta.validation.constraints.*;
public record VaccineRequest(@NotBlank String name,@NotBlank String code,@NotBlank String category,@Positive short maxDoses,Integer minAgeMonths,Integer maxAgeMonths,boolean hasLaboratory,boolean hasLot,boolean hasSyringe,boolean hasSyringeLot,boolean hasDiluent,boolean hasDropper,boolean hasPneumococcalType,boolean hasVialCount,boolean hasObservation) {}
