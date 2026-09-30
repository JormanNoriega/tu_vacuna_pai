package com.pai.api.catalog.dto;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class OptionRequestValidationTest {

  private static final Validator VALIDATOR =
      Validation.buildDefaultValidatorFactory().getValidator();

  private static OptionRequest request(
      String fieldType, String value, String displayName, int sortOrder) {
    return new OptionRequest(fieldType, value, displayName, sortOrder, false, true, 0L);
  }

  private static Set<String> violations(OptionRequest request) {
    return VALIDATOR.validate(request).stream()
        .map(violation -> violation.getPropertyPath().toString())
        .collect(Collectors.toSet());
  }

  @Test
  void acceptsValuesAtTheLimits() {
    assertThat(violations(request("x".repeat(40), "v".repeat(120), "d".repeat(120), 9999)))
        .isEmpty();
  }

  @Test
  void rejectsTextBeyondLimits() {
    assertThat(violations(request("x".repeat(41), "v".repeat(121), "d".repeat(121), 0)))
        .contains("fieldType", "value", "displayName");
  }

  @Test
  void rejectsSortOrderOutOfRange() {
    assertThat(violations(request("dose", "1", "Dosis 1", -1))).contains("sortOrder");
    assertThat(violations(request("dose", "1", "Dosis 1", 10000))).contains("sortOrder");
  }
}
