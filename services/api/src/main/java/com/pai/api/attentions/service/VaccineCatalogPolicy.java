package com.pai.api.attentions.service;

import java.util.UUID;

/**
 * Puerto de seleccion del catalogo de vacunas utilizado por el modulo clinico
 * al registrar una dosis.
 *
 * <p>Aplica el principio de inversion de dependencias (DIP) en la frontera de
 * modulos: {@code AttentionService} depende de esta abstraccion y no de los
 * repositorios JPA del modulo {@code catalog}. Una implementacion vive en el
 * modulo catalogo y conoce sus entidades y repositorios.
 *
 * <p>El puerto no expone entidades JPA: devuelve un valor inerte
 * ({@link DoseSelection}) con los datos que el agregado de dosis necesita para
 * construir su snapshot, lo que mantiene la frontera del modulo clinico
 * desacoplada del modelo de persistencia del catalogo.
 */
public interface VaccineCatalogPolicy {

  /**
   * Datos validados del catalogo necesarios para registrar una dosis
   * (snapshot que quedara grabado en {@code AppliedDoseEntity}).
   */
  record DoseSelection(
      UUID vaccineId,
      String vaccineName,
      String vaccineCode,
      long catalogVersion,
      UUID doseOptionId,
      String doseLabel,
      String doseValue,
      UUID pneumococcalTypeOptionId,
      String pneumococcalTypeSnapshot,
      UUID laboratoryId,
      String laboratorySnapshot,
      UUID syringeId,
      String syringeSnapshot,
      UUID dropperId,
      String dropperSnapshot,
      UUID observationId,
      String observationSnapshot) {}

  /** Seleccion del clinico de los campos de la dosis, tal como llega de la UI. */
  record ResolutionRequest(
      UUID institutionId,
      UUID vaccineId,
      UUID doseOptionId,
      UUID pneumococcalTypeOptionId,
      UUID laboratoryId,
      UUID syringeId,
      UUID dropperId,
      UUID observationId) {}

  /**
   * Valida la seleccion (vacuna habilitada e institucional, opciones globales
   * validas, opciones operativas institucionales) y devuelve el snapshot.
   *
   * <p>Lanza las mismas excepciones de dominio que antes se centralizaban en
   * {@code AttentionService}: {@code IllegalArgumentException} para seleccion
   * invalida y {@code InvalidClinicalStateException} para vacuna inactiva o no
   * habilitada.
   */
  DoseSelection resolve(ResolutionRequest request);
}
