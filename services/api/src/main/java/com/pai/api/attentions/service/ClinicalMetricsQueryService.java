package com.pai.api.attentions.service;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.reports.service.ClinicalMetricsQuery;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Implementacion de {@link ClinicalMetricsQuery} en el modulo {@code attentions}
 * (DIP): encapsula las queries agregadas y el filtro de anuladas, de modo que
 * {@code reports} no depende de sus repositorios ni de sus enums.
 */
@Service
public class ClinicalMetricsQueryService implements ClinicalMetricsQuery {

  private final AttentionRepository attentions;
  private final AppliedDoseRepository doses;

  public ClinicalMetricsQueryService(AttentionRepository attentions, AppliedDoseRepository doses) {
    this.attentions = attentions;
    this.doses = doses;
  }

  @Override
  @Transactional(readOnly = true)
  public long patientsAttended(UUID institutionId) {
    return attentions.countDistinctPatientsByInstitutionId(
        institutionId, AttentionEntity.Status.CANCELLED);
  }

  @Override
  @Transactional(readOnly = true)
  public long dosesApplied(UUID institutionId) {
    return doses.countByInstitutionId(institutionId, AppliedDoseEntity.Status.CANCELLED);
  }
}
