package com.pai.api.reports.dto;

import java.time.Instant;
import java.util.List;

public record StatisticsDashboardResponse(
    PeriodResponse period,
    KpisResponse kpis,
    List<TimePointResponse> doseSeries,
    List<VaccineDistributionResponse> vaccineDistribution,
    List<VaccinatorProductivityResponse> vaccinatorProductivity,
    DataStatusResponse status) {

  public record PeriodResponse(Instant from, Instant to, String granularity) {}

  public record KpisResponse(
      long dosesApplied,
      long uniquePatients,
      long activeVaccinators,
      long dosesPerPatient) {}

  public record TimePointResponse(String label, Instant start, long doses, long uniquePatients) {}

  public record VaccineDistributionResponse(
      String name,
      String code,
      long doses,
      double percentage) {}

  public record VaccinatorProductivityResponse(
      String vaccinatorId,
      String name,
      long doses,
      long uniquePatients) {}

  public record DataStatusResponse(Instant generatedAt, String source) {}
}
