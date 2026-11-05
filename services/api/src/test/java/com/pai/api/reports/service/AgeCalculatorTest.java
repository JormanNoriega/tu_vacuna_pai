package com.pai.api.reports.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class AgeCalculatorTest {

  @Test
  void calculatesExactAgeComponents() {
    LocalDate birth = LocalDate.of(2024, 1, 15);
    LocalDate reference = LocalDate.of(2026, 3, 20);

    AgeCalculator.Age age = AgeCalculator.calculate(birth, reference);

    assertThat(age.years()).isEqualTo(2);
    assertThat(age.months()).isEqualTo(2);
    assertThat(age.days()).isEqualTo(5);
    assertThat(age.totalMonths()).isEqualTo(26);
  }

  @Test
  void handlesFutureBirthDate() {
    LocalDate birth = LocalDate.of(2026, 5, 1);
    LocalDate reference = LocalDate.of(2026, 3, 20);

    AgeCalculator.Age age = AgeCalculator.calculate(birth, reference);

    assertThat(age.years()).isZero();
    assertThat(age.months()).isZero();
    assertThat(age.days()).isZero();
    assertThat(age.totalMonths()).isZero();
  }
}
