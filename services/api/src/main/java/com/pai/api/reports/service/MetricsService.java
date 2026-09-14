package com.pai.api.reports.service;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.reports.dto.MetricsSummaryResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Metricas agregadas del home, acotadas a la institucion del actor (ADR-007).
 *
 * <p>Los dos indicadores son acumulados historicos y excluyen las atenciones y
 * dosis anuladas.
 */
@Service
public class MetricsService {

  private final AttentionRepository attentions;
  private final AppliedDoseRepository doses;
  private final DataScope dataScope;

  public MetricsService(
      AttentionRepository attentions, AppliedDoseRepository doses, DataScope dataScope) {
    this.attentions = attentions;
    this.doses = doses;
    this.dataScope = dataScope;
  }

  @Transactional(readOnly = true)
  public MetricsSummaryResponse summary(AuthorizedUser actor) {
    UUID institutionId =
        dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    long patientsAttended = attentions.countDistinctPatientsByInstitutionId(
        institutionId, AttentionEntity.Status.CANCELLED);
    long dosesApplied =
        doses.countByInstitutionId(institutionId, AppliedDoseEntity.Status.CANCELLED);
    return new MetricsSummaryResponse(patientsAttended, dosesApplied);
  }
}
