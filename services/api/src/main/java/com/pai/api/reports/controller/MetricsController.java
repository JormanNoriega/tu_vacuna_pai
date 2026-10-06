package com.pai.api.reports.controller;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.reports.dto.MetricsSummaryResponse;
import com.pai.api.reports.service.MetricsService;
import com.pai.api.shared.security.ActorResolver;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Metricas del home. La institucion se deriva del actor; el cliente nunca la
 * envia (ADR-007).
 */
@RestController
@RequestMapping("/api/v1/metrics")
public class MetricsController {

  private final MetricsService service;

  public MetricsController(MetricsService service) {
    this.service = service;
  }

  @GetMapping("/summary")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<MetricsSummaryResponse> summary(Authentication authentication) {
    AuthorizedUser actor = ActorResolver.resolve(authentication);
    return ResponseEntity.ok(service.summary(actor));
  }
}
