package com.pai.api.reports.controller;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.reports.dto.MetricsSummaryResponse;
import com.pai.api.reports.dto.RecentRecordResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse;
import com.pai.api.reports.service.MetricsService;
import com.pai.api.reports.service.StatisticsService;
import com.pai.api.shared.security.ActorResolver;
import java.time.Instant;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Metricas del home. La institucion se deriva del actor; el cliente nunca la
 * envia (ADR-007).
 */
@RestController
@RequestMapping("/api/v1/metrics")
public class MetricsController {

  private final MetricsService service;
  private final StatisticsService statistics;

  public MetricsController(MetricsService service, StatisticsService statistics) {
    this.service = service;
    this.statistics = statistics;
  }

  @GetMapping("/summary")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<MetricsSummaryResponse> summary(Authentication authentication) {
    AuthorizedUser actor = ActorResolver.resolve(authentication);
    return ResponseEntity.ok(service.summary(actor));
  }

  @GetMapping("/recent")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<List<RecentRecordResponse>> recent(Authentication authentication) {
    AuthorizedUser actor = ActorResolver.resolve(authentication);
    return ResponseEntity.ok(service.recentRecords(actor, 5));
  }

  @GetMapping("/statistics/dashboard")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<StatisticsDashboardResponse> statisticsDashboard(
      Authentication authentication,
      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
      @RequestParam(defaultValue = "day") String granularity) {
    AuthorizedUser actor = ActorResolver.resolve(authentication);
    return ResponseEntity.ok(statistics.dashboard(actor, from, to, granularity));
  }
}
