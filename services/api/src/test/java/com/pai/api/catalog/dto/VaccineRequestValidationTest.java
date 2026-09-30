package com.pai.api.catalog.dto;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class VaccineRequestValidationTest {

  private static final Validator VALIDATOR =
      Validation.buildDefaultValidatorFactory().getValidator();

  private static VaccineRequest request(
      String name,
      String code,
      String category,
      short maxDoses,
      Integer minAgeMonths,
      Integer maxAgeMonths) {
    return new VaccineRequest(
        name,
        code,
        category,
        maxDoses,
        minAgeMonths,
        maxAgeMonths,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false);
  }

  private static Set<String> violations(VaccineRequest request) {
    return VALIDATOR.validate(request).stream()
        .map(violation -> violation.getPropertyPath().toString())
        .collect(Collectors.toSet());
  }

  @Test
  void acceptsValuesAtTheLimits() {
    assertThat(violations(
            request("a".repeat(120), "c".repeat(40), "x".repeat(60), (short) 100, 0, 240)))
        .isEmpty();
  }

  @Test
  void rejectsTextBeyondLimits() {
    assertThat(
            violations(request("a".repeat(121), "c".repeat(41), "x".repeat(61), (short) 1, 0, 240)))
        .contains("name", "code", "category");
  }

  @Test
  void rejectsMaxDosesOutOfRange() {
    assertThat(violations(request("Vacuna", "VAC", "Cat", (short) 0, 0, 240))).contains("maxDoses");
    assertThat(violations(request("Vacuna", "VAC", "Cat", (short) 101, 0, 240)))
        .contains("maxDoses");
  }

  @Test
  void rejectsAgesOutOfRange() {
    assertThat(violations(request("Vacuna", "VAC", "Cat", (short) 1, -1, 240)))
        .contains("minAgeMonths");
    assertThat(violations(request("Vacuna", "VAC", "Cat", (short) 1, 0, 241)))
        .contains("maxAgeMonths");
  }

  @Test
  void rejectsInvertedAgeRange() {
    assertThat(violations(request("Vacuna", "VAC", "Cat", (short) 1, 120, 60)))
        .contains("ageRangeValid");
  }
}
