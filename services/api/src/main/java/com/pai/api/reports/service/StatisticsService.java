package com.pai.api.reports.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.reports.dto.StatisticsDashboardResponse;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class StatisticsService {

  private final StatisticsQuery query;
  private final DataScope dataScope;

  public StatisticsService(StatisticsQuery query, DataScope dataScope) {
    this.query = query;
    this.dataScope = dataScope;
  }

  public StatisticsDashboardResponse dashboard(
      AuthorizedUser actor,
      Instant from,
      Instant to,
      String granularity) {
    Objects.requireNonNull(from, "from es obligatorio");
    Objects.requireNonNull(to, "to es obligatorio");
    if (!from.isBefore(to)) {
      throw new IllegalArgumentException("El inicio del periodo debe ser anterior al final.");
    }

    UUID institutionId = dataScope.institutionOf(actor);
    return query.dashboard(institutionId, from, to, granularity);
  }
}
