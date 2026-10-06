package com.pai.api.reports.service;

import com.pai.api.reports.domain.RegistroDiarioDoseData;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Puerto (DIP): dosis aplicadas de la institucion en un rango de fechas, con sus
 * datos de atencion. Lo implementa el modulo {@code attentions}, de modo que
 * {@code reports} no depende de su persistencia ni de sus entidades.
 */
public interface RegistroDiarioQuery {

  List<RegistroDiarioDoseData> doses(UUID institutionId, Instant from, Instant to);
}
