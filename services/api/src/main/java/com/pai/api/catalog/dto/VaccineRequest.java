package com.pai.api.catalog.dto;

import jakarta.validation.constraints.*;

public record VaccineRequest(
    @NotBlank(message = "El nombre es obligatorio.")
    @Size(max = 120, message = "El nombre no puede superar 120 caracteres.")
    String name,

    @NotBlank(message = "El codigo es obligatorio.")
    @Size(max = 40, message = "El codigo no puede superar 40 caracteres.")
    String code,

    @NotBlank(message = "La categoria es obligatoria.")
    @Size(max = 60, message = "La categoria no puede superar 60 caracteres.")
    String category,

    @Min(value = 1, message = "El numero maximo de dosis debe ser al menos 1.")
    @Max(value = 100, message = "El numero maximo de dosis no puede superar 100.")
    short maxDoses,

    @Min(value = 0, message = "La edad minima no puede ser negativa.")
    @Max(value = 240, message = "La edad minima no puede superar 240 meses.")
    Integer minAgeMonths,

    @Min(value = 0, message = "La edad maxima no puede ser negativa.")
    @Max(value = 240, message = "La edad maxima no puede superar 240 meses.")
    Integer maxAgeMonths,

    boolean hasLaboratory,
    boolean hasLot,
    boolean hasSyringe,
    boolean hasSyringeLot,
    boolean hasDiluent,
    boolean hasDropper,
    boolean hasPneumococcalType,
    boolean hasVialCount,
    boolean hasObservation) {

  @AssertTrue(message = "La edad minima no puede superar la edad maxima.")
  public boolean isAgeRangeValid() {
    if (minAgeMonths == null || maxAgeMonths == null) {
      return true;
    }
    return minAgeMonths <= maxAgeMonths;
  }
}
