import 'package:flutter/services.dart';

/// Limites de longitud coherentes con las validaciones `@Size` del backend.
abstract final class FieldLimits {
  // ---------- Paciente / atencion ----------
  static const name = 120;
  static const ethnicity = 80;
  static const educationLevel = 120;
  static const phone = 10;
  static const email = 120;
  static const street = 200;
  static const historyCondition = 200;
  static const historyNotes = 500;
  static const lotNumber = 60;
  static const attentionObservations = 2000;

  // ---------- Documento ----------
  // El tope del documento de paciente depende del tipo: ver [documentRules]
  // (fuente unica). El personal de salud si usa un tope fijo (staffDocument).
  static const patientDocument = 20;
  static const staffDocument = 40;

  // ---------- Paciente ampliado ----------
  static const birthPlace = 200;
  static const migrationStatus = 20;
  static const vaccinationCardType = 40;
  static const contactValue = 120;
  static const locality = 120;
  static const area = 20;
  static const guardianName = 120;
  static const guardianPhone = 10;
  static const guardianEmail = 120;
  static const affiliationRegime = 40;
  static const insurer = 120;
  static const contraindicationDetails = 120;
  static const reactionDetails = 120;
  static const historyType = 60;
  static const specialObservations = 500;

  // ---------- Identidad / personal de salud ----------
  static const fullName = 200;
  static const staffEmail = 255;
  static const staffPhone = 20;
  static const professionCode = 50;
  static const registrationNumber = 60;
  static const registrationType = 60;
  static const password = 128;

  // ---------- Catalogo ----------
  static const vaccineName = 120;
  static const vaccineCode = 40;
  static const category = 60;
  static const optionValue = 120;
  static const optionDisplayName = 120;

  // ---------- Institucion ----------
  static const institutionCode = 32;
  static const institutionName = 200;

  // ---------- Atencion ----------
  static const reason = 500;

  // ---------- Cotas numericas (validacion de rango) ----------
  static const vialCountMin = 0;
  static const vialCountMax = 999;
  static const maxDosesMin = 1;
  static const maxDosesMax = 100;
  static const ageMonthsMin = 0;
  static const ageMonthsMax = 240;
  static const sortOrderMax = 9999;
  static const offlineWindowMin = 1;
  static const offlineWindowMax = 168;
}

/// Solo limita la longitud (para campos de texto libre).
List<TextInputFormatter> maxLengthFormatters(int max) => [
  LengthLimitingTextInputFormatter(max),
];

/// Teclado + restriccion para telefonos: solo digitos, maximo [max]
/// (Colombia: indicativo + numero, hasta 10 digitos).
List<TextInputFormatter> phoneFormatters({int max = FieldLimits.phone}) => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(max),
];

/// Teclado + restriccion para cantidades numericas: solo digitos, con
/// longitud maxima opcional [max] derivada del rango de negocio.
List<TextInputFormatter> digitsOnlyFormatters({int? max}) => [
  FilteringTextInputFormatter.digitsOnly,
  if (max != null) LengthLimitingTextInputFormatter(max),
];
