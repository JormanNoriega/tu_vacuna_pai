package com.pai.api.reports.service;

import java.time.LocalDate;
import java.time.Period;

/**
 * Calculador de edad exacta (anos, meses, dias, total de meses) segun el calendario.
 */
public final class AgeCalculator {

  private AgeCalculator() {}

  public record Age(int years, int months, int days, int totalMonths) {}

  public static Age calculate(LocalDate birthDate, LocalDate referenceDate) {
    if (birthDate == null || referenceDate == null || birthDate.isAfter(referenceDate)) {
      return new Age(0, 0, 0, 0);
    }
    Period period = Period.between(birthDate, referenceDate);
    int years = Math.max(0, period.getYears());
    int months = Math.max(0, period.getMonths());
    int days = Math.max(0, period.getDays());
    int totalMonths = years * 12 + months;
    return new Age(years, months, days, totalMonths);
  }
}
