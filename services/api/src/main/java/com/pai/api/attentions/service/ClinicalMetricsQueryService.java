package com.pai.api.attentions.service;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.reports.domain.PatientIdentity;
import com.pai.api.reports.dto.RecentRecordResponse;
import com.pai.api.reports.service.ClinicalMetricsQuery;
import com.pai.api.reports.service.PatientIdentityQuery;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
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
  private final PatientIdentityQuery patientIdentities;

  public ClinicalMetricsQueryService(
      AttentionRepository attentions,
      AppliedDoseRepository doses,
      PatientIdentityQuery patientIdentities) {
    this.attentions = attentions;
    this.doses = doses;
    this.patientIdentities = patientIdentities;
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

  @Override
  @Transactional(readOnly = true)
  public long patientsAttendedByProfessional(UUID institutionId, UUID professionalId) {
    return attentions.countDistinctPatientsByInstitutionIdAndProfessionalId(
        institutionId, professionalId, AttentionEntity.Status.CANCELLED);
  }

  @Override
  @Transactional(readOnly = true)
  public long dosesAppliedByProfessional(UUID institutionId, UUID professionalId) {
    return doses.countByInstitutionIdAndProfessionalId(
        institutionId, professionalId, AppliedDoseEntity.Status.CANCELLED);
  }

  @Override
  @Transactional(readOnly = true)
  public List<RecentRecordResponse> recentRecords(
      UUID institutionId, UUID professionalId, boolean isInstitutionalAdmin, int limit) {
    if (isInstitutionalAdmin || professionalId == null) {
      return List.of();
    }

    List<AttentionEntity> attentionList =
        attentions
            .findTop5ByInstitutionIdAndProfessionalIdAndStatusNotOrderByAttentionDateDescCreatedAtDesc(
                institutionId, professionalId, AttentionEntity.Status.CANCELLED);

    if (attentionList.isEmpty()) {
      return List.of();
    }

    Set<UUID> patientIds =
        attentionList.stream().map(AttentionEntity::getPatientId).collect(Collectors.toSet());
    Map<UUID, String> patientNames =
        patientIdentities.byIds(patientIds).stream()
            .collect(
                Collectors.toMap(
                    PatientIdentity::id,
                    p -> (p.firstName() + " " + p.lastName()).trim()));

    Set<UUID> attentionIds =
        attentionList.stream().map(AttentionEntity::getId).collect(Collectors.toSet());
    List<AppliedDoseEntity> doseList =
        doses.findByAttentionIdInOrderByCreatedAtAsc(attentionIds);
    Map<UUID, String> vaccineByAttention =
        doseList.stream()
            .collect(
                Collectors.toMap(
                    AppliedDoseEntity::getAttentionId,
                    AppliedDoseEntity::getVaccineNameSnapshot,
                    (existing, replacement) -> existing + ", " + replacement));

    List<RecentRecordResponse> records = new ArrayList<>();
    for (AttentionEntity a : attentionList) {
      String pName = patientNames.getOrDefault(a.getPatientId(), "Paciente");
      String vName = vaccineByAttention.getOrDefault(a.getId(), "Atención de vacunación");
      Instant timestamp = a.getCreatedAt() != null ? a.getCreatedAt() : a.getAttentionDate();
      records.add(new RecentRecordResponse(a.getId(), a.getPatientId(), pName, vName, timestamp));
    }
    return records;
  }
}
