package com.pai.api.reports.service;

import com.pai.api.reports.dto.StatisticsDashboardResponse;
import java.time.Instant;
import java.util.UUID;

public interface StatisticsQuery {
  StatisticsDashboardResponse dashboard(
      UUID institutionId,
      Instant from,
      Instant to,
      String granularity);
}
