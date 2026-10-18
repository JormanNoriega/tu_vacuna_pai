package com.pai.api.attentions.dto;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class CreateAttentionRequestValidationTest {

  private static final Validator VALIDATOR =
      Validation.buildDefaultValidatorFactory().getValidator();

  private static CreateAttentionRequest request(Double latitude, Double longitude) {
    return new CreateAttentionRequest(
        UUID.randomUUID(),
        null,
        null,
        null,
        null,
        null,
        latitude,
        longitude);
  }

  private static Set<String> violations(CreateAttentionRequest request) {
    return VALIDATOR.validate(request).stream()
        .map(violation -> violation.getPropertyPath().toString())
        .collect(Collectors.toSet());
  }

  @Test
  void acceptsCoordinatesWithinValidRange() {
    assertThat(violations(request(4.60971, -74.08175))).isEmpty();
    assertThat(violations(request(-90.0, -180.0))).isEmpty();
    assertThat(violations(request(90.0, 180.0))).isEmpty();
    assertThat(violations(request(null, null))).isEmpty();
  }

  @Test
  void rejectsCoordinatesOutOfRange() {
    assertThat(violations(request(-90.0001, 0.0))).contains("latitude");
    assertThat(violations(request(90.0001, 0.0))).contains("latitude");
    assertThat(violations(request(0.0, -180.0001))).contains("longitude");
    assertThat(violations(request(0.0, 180.0001))).contains("longitude");
  }
}
