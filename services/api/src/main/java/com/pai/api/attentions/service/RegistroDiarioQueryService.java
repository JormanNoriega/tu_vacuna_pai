package com.pai.api.attentions.service;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.reports.domain.RegistroDiarioDoseData;
import com.pai.api.reports.service.RegistroDiarioQuery;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Implementacion de {@link RegistroDiarioQuery} en el modulo {@code attentions}
 * (DIP): devuelve las dosis aplicadas (no anuladas) de la institucion con los
 * datos de su atencion y el {@code patientId}. No accede a la persistencia de
 * pacientes; la identidad la cruza {@code reports} via {@code PatientIdentityQuery}.
 *
 * <p>Consultas en bloque: atenciones del rango y luego sus dosis (evita N+1).
 */
@Service
public class RegistroDiarioQueryService implements RegistroDiarioQuery {

  private final AttentionRepository attentions;
  private final AppliedDoseRepository doses;

  public RegistroDiarioQueryService(AttentionRepository attentions, AppliedDoseRepository doses) {
    this.attentions = attentions;
    this.doses = doses;
  }

  @Override
  @Transactional(readOnly = true)
  public List<RegistroDiarioDoseData> doses(UUID institutionId, Instant from, Instant to) {
    List<AttentionEntity> attentionList =
        attentions.findByInstitutionIdAndAttentionDateBetweenOrderByAttentionDateAsc(
            institutionId, from, to);
    if (attentionList.isEmpty()) {
      return List.of();
    }

    Map<UUID, AttentionEntity> attentionById =
        attentionList.stream()
            .collect(Collectors.toMap(AttentionEntity::getId, attention -> attention));

    List<AppliedDoseEntity> doseList =
        doses.findByAttentionIdInOrderByCreatedAtAsc(new ArrayList<>(attentionById.keySet()));

    List<RegistroDiarioDoseData> rows = new ArrayList<>();
    for (AppliedDoseEntity dose : doseList) {
      if (dose.getStatus() == AppliedDoseEntity.Status.CANCELLED) {
        continue;
      }
      AttentionEntity attention = attentionById.get(dose.getAttentionId());
      if (attention == null) {
        continue;
      }
      rows.add(
          new RegistroDiarioDoseData(
              attention.getConsecutive(),
              attention.getAttentionDate(),
              attention.getPatientId(),
              dose.getVaccineNameSnapshot(),
              dose.getVaccineCodeSnapshot(),
              dose.getDoseLabelSnapshot(),
              dose.getLotNumber(),
              dose.getSelectedLaboratorySnapshot(),
              dose.getSelectedSyringeSnapshot(),
              dose.getSelectedDropperSnapshot(),
              dose.getSelectedObservationSnapshot(),
              dose.getApplicationDate(),
              dose.getStatus().name()));
    }
    return rows;
  }
}
