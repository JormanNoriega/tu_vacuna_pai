package com.pai.api.reports.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.reports.dto.MetricsSummaryResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Metricas agregadas del home, acotadas a la institucion del actor (ADR-007).
 *
 * <p>El calculo de los indicadores clinicos se delega en el puerto
 * {@link ClinicalMetricsQuery} (DIP): {@code reports} no conoce los repositorios
 * ni los enums del modulo {@code attentions}.
 */
@Service
public class MetricsService {

  private final ClinicalMetricsQuery metrics;
  private final DataScope dataScope;

  public MetricsService(ClinicalMetricsQuery metrics, DataScope dataScope) {
    this.metrics = metrics;
    this.dataScope = dataScope;
  }

  @Transactional(readOnly = true)
  public MetricsSummaryResponse summary(AuthorizedUser actor) {
    UUID institutionId = dataScope.institutionOf(actor);
    return new MetricsSummaryResponse(
        metrics.patientsAttended(institutionId), metrics.dosesApplied(institutionId));
  }
}
