package com.pai.api.patients.service;

import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.entity.PatientGuardianEntity;
import com.pai.api.shared.util.DocumentNormalizer;
import com.pai.api.shared.util.Strings;
import java.time.LocalDate;

/**
 * Reglas de negocio del alta y actualizacion de pacientes (SRP). Extraidas de
 * {@code PatientService} para que la orquestacion no mezcle validaciones.
 */
public final class PatientRules {

  /** Maximo de digitos de un telefono (indicativo + numero, Colombia). */
  private static final int MAX_PHONE_DIGITS = 10;

  private PatientRules() {}

  /** Exige tipo y numero de documento y valida el formato segun el tipo. */
  public static void validateDocument(String documentType, String documentNumber) {
    if (documentType == null || documentNumber == null) {
      throw new IllegalArgumentException("El tipo y el numero de documento son obligatorios.");
    }
    if (!DocumentNormalizer.isValidForType(documentNumber, documentType)) {
      throw new IllegalArgumentException(
          "El numero de documento no es valido para el tipo indicado.");
    }
  }

  /** Los contactos de tipo telefono no pueden superar 10 digitos. */
  public static void validatePhone(String type, String value) {
    if (type == null || value == null || !"PHONE".equalsIgnoreCase(type.trim())) {
      return;
    }
    String digits = value.replaceAll("\\D", "");
    if (digits.length() > MAX_PHONE_DIGITS) {
      throw new IllegalArgumentException("El telefono no puede superar 10 digitos.");
    }
  }

  /**
   * Un menor de 18 anios exige un tutor (madre o cuidador) con los campos base
   * del formato PAI; si el parentesco es {@code MOTHER}, exige ademas regimen,
   * etnia y desplazado. Regla de negocio (no expresable con Bean Validation).
   */
  public static void validateGuardianForMinor(CreatePatientRequest request) {
    LocalDate birthDate = request.birthDate();
    if (birthDate == null) {
      return; // Bean Validation ya exige la fecha de nacimiento.
    }
    boolean isMinor = birthDate.isAfter(LocalDate.now().minusYears(18));
    if (!isMinor) {
      return;
    }
    boolean hasValidGuardian = Strings.safe(request.guardians()).stream().anyMatch(guardian -> {
      if (Strings.blankToNull(guardian.fullName()) == null
          || Strings.blankToNull(guardian.documentNumber()) == null) {
        return false;
      }
      boolean isMother = PatientGuardianEntity.Relationship.MOTHER
          .name()
          .equalsIgnoreCase(Strings.blankToNull(guardian.relationship()));
      if (isMother) {
        return Strings.blankToNull(guardian.affiliationRegime()) != null
            && Strings.blankToNull(guardian.ethnicity()) != null
            && guardian.displaced() != null;
      }
      return true;
    });
    if (!hasValidGuardian) {
      throw new IllegalArgumentException(
          "El tutor (madre o cuidador) es obligatorio para menores de edad, con nombre y"
              + " documento.");
    }
  }
}
