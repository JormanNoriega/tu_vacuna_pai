package com.pai.api.attentions.dto;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class RegisterDoseRequestValidationTest {

  private static final Validator VALIDATOR =
      Validation.buildDefaultValidatorFactory().getValidator();

  private static RegisterDoseRequest request(Integer vialCount) {
    return new RegisterDoseRequest(
        UUID.randomUUID(),
        UUID.randomUUID(),
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        vialCount,
        null);
  }

  private static Set<String> violations(RegisterDoseRequest request) {
    return VALIDATOR.validate(request).stream()
        .map(violation -> violation.getPropertyPath().toString())
        .collect(Collectors.toSet());
  }

  @Test
  void acceptsVialCountAtTheLimits() {
    assertThat(violations(request(0))).isEmpty();
    assertThat(violations(request(999))).isEmpty();
    assertThat(violations(request(null))).isEmpty();
  }

  @Test
  void rejectsVialCountOutOfRange() {
    assertThat(violations(request(-1))).contains("vialCount");
    assertThat(violations(request(1000))).contains("vialCount");
  }
}
