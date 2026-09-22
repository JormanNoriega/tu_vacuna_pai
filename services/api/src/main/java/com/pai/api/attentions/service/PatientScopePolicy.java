package com.pai.api.attentions.service;

import java.util.UUID;

/**
 * Puerto de verificacion del alcance institucional de un paciente.
 *
 * <p>Aplica el principio de inversion de dependencias (DIP) en la frontera de
 * modulos: {@code AttentionService} depende de esta abstraccion y no del
 * repositorio JPA del modulo {@code patients}. Una implementacion vive en el
 * modulo {@code patients} y conoce su persistencia.
 */
public interface PatientScopePolicy {

  /**
   * Indica si el paciente existe y pertenece a la institucion indicada. El
   * alcance se deriva del actor (ADR-007); la institucion nunca se confia al
   * cliente.
   */
  boolean existsInInstitution(UUID patientId, UUID institutionId);
}
