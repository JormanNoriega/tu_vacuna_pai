package com.pai.api.reports.service;

import com.pai.api.reports.domain.PatientIdentity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Puerto (DIP): identidad de pacientes por id. Lo implementa el modulo
 * {@code patients}, de modo que {@code reports} no depende de su persistencia ni
 * de sus entidades.
 */
public interface PatientIdentityQuery {

  List<PatientIdentity> byIds(Collection<UUID> patientIds);
}
