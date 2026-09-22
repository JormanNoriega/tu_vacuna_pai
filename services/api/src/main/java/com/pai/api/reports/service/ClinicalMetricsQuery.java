package com.pai.api.reports.service;

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
}
