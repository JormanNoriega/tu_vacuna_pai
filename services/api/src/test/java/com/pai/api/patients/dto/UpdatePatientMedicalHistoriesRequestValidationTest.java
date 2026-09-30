package com.pai.api.patients.dto;

import static org.assertj.core.api.Assertions.assertThat;

import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest.MedicalHistoryDto;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

class UpdatePatientMedicalHistoriesRequestValidationTest {

  private static final Validator VALIDATOR =
      Validation.buildDefaultValidatorFactory().getValidator();

  private static UpdatePatientMedicalHistoriesRequest request(
      String notes,
      String contraindicationDetails,
      String reactionDetails,
      String historyType,
      String specialObservations) {
    MedicalHistoryDto history = new MedicalHistoryDto(
        "Asma",
        null,
        notes,
        false,
        contraindicationDetails,
        false,
        reactionDetails,
        historyType,
        specialObservations);
    return new UpdatePatientMedicalHistoriesRequest(List.of(history));
  }

  private static Set<String> violations(UpdatePatientMedicalHistoriesRequest request) {
    return VALIDATOR.validate(request).stream()
        .map(violation -> violation.getPropertyPath().toString())
        .collect(Collectors.toSet());
  }

  @Test
  void acceptsValuesAtTheLimits() {
    assertThat(violations(request(
            "n".repeat(500), "c".repeat(120), "r".repeat(120), "t".repeat(60), "o".repeat(500))))
        .isEmpty();
  }

  @Test
  void rejectsTextBeyondLimits() {
    assertThat(violations(request(
            "n".repeat(501), "c".repeat(121), "r".repeat(121), "t".repeat(61), "o".repeat(501))))
        .contains(
            "medicalHistories[0].notes",
            "medicalHistories[0].contraindicationDetails",
            "medicalHistories[0].reactionDetails",
            "medicalHistories[0].historyType",
            "medicalHistories[0].specialObservations");
  }
}
