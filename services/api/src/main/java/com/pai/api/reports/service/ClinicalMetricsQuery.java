package com.pai.api.reports.service;

import com.pai.api.reports.dto.RecentRecordResponse;
import java.util.List;
import java.util.UUID;

/**
 * Puerto (DIP) de metricas clinicas agregadas por institucion. Lo define el
 * modulo {@code reports} y lo implementa {@code attentions}, de modo que
 * reportes no depende de la persistencia ni de los enums del modulo clinico.
 *
 * <p>Los indicadores son acumulados historicos y excluyen las atenciones y
 * dosis anuladas (ese filtro vive en la implementacion).
 */
public interface ClinicalMetricsQuery {

  /** Pacientes distintos con al menos una atencion no anulada en la institucion. */
  long patientsAttended(UUID institutionId);

  /** Dosis no anuladas aplicadas en la institucion. */
  long dosesApplied(UUID institutionId);

  /** Pacientes distintos con al menos una atencion no anulada atendidos por un profesional especifico. */
  long patientsAttendedByProfessional(UUID institutionId, UUID professionalId);

  /** Dosis no anuladas aplicadas por un profesional especifico en la institucion. */
  long dosesAppliedByProfessional(UUID institutionId, UUID professionalId);

  /** Ultimos registros de atencion no anulados. */
  List<RecentRecordResponse> recentRecords(
      UUID institutionId, UUID professionalId, boolean isInstitutionalAdmin, int limit);
}
