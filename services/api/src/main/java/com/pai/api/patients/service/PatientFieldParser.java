package com.pai.api.patients.service;

import com.pai.api.patients.entity.PatientContactEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientGender;
import com.pai.api.patients.entity.PatientGuardianEntity;
import com.pai.api.shared.util.Strings;

/**
 * Parseo y normalizacion de los campos del paciente (SRP): convierte los
 * valores crudos del request a los tipos de dominio del agregado.
 */
public final class PatientFieldParser {

  private PatientFieldParser() {}

  /** Sexo del paciente ({@code MALE}, {@code FEMALE}, {@code INDETERMINATE}). */
  public static PatientEntity.Sex sex(String raw) {
    return parse(PatientEntity.Sex.class, raw, "Sexo invalido. Usa MALE, FEMALE o INDETERMINATE.");
  }

  /** Tipo de contacto ({@code PHONE}, {@code EMAIL}, ...). */
  public static PatientContactEntity.Type contactType(String raw) {
    return parse(PatientContactEntity.Type.class, raw, "Tipo de contacto invalido.");
  }

  /** Parentesco del tutor ({@code MOTHER}, {@code FATHER}, {@code CAREGIVER}, {@code OTHER}). */
  public static PatientGuardianEntity.Relationship relationship(String raw) {
    return parse(
        PatientGuardianEntity.Relationship.class,
        raw,
        "Parentesco invalido. Usa MOTHER, FATHER, CAREGIVER u OTHER.");
  }

  /** Normaliza catalogos de referencia a su codigo en mayusculas. */
  public static String normalizeUpper(String value) {
    String trimmed = Strings.blankToNull(value);
    return trimmed == null ? null : trimmed.toUpperCase();
  }

  /**
   * Normaliza y valida el genero demografico; {@code null} si viene vacio. El
   * vocabulario vive en {@link PatientGender} (distinto del sexo del paciente).
   */
  public static String normalizeGender(String raw) {
    if (Strings.blankToNull(raw) == null) {
      return null;
    }
    return parse(
            PatientGender.class,
            raw,
            "Genero invalido. Usa FEMALE, MALE, OTHER, TRANSGENDER o INDETERMINATE.")
        .name();
  }

  private static <E extends Enum<E>> E parse(Class<E> type, String raw, String message) {
    try {
      return Enum.valueOf(type, raw.trim().toUpperCase());
    } catch (IllegalArgumentException | NullPointerException ex) {
      throw new IllegalArgumentException(message);
    }
  }
}
