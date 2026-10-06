package com.pai.api.patients.entity;

/**
 * Genero demografico del paciente ({@code patient_demographics.gender}).
 * Vocabulario distinto de {@link PatientEntity.Sex} (sexo biologico): el genero
 * admite identidades adicionales.
 */
public enum PatientGender {
  FEMALE,
  MALE,
  OTHER,
  TRANSGENDER,
  INDETERMINATE
}
