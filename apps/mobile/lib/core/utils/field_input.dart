import 'package:flutter/services.dart';

/// Limites de longitud coherentes con las validaciones `@Size` del backend.
abstract final class FieldLimits {
  static const name = 120;
  static const ethnicity = 80;
  static const educationLevel = 120;
  static const phone = 20;
  static const email = 120;
  static const street = 200;
  static const historyCondition = 200;
  static const historyNotes = 500;
  static const lotNumber = 60;
  static const attentionObservations = 2000;
}

/// Solo limita la longitud (para campos de texto libre).
List<TextInputFormatter> maxLengthFormatters(int max) => [
  LengthLimitingTextInputFormatter(max),
];

/// Teclado + restriccion para telefonos (digitos y simbolos de marcado).
List<TextInputFormatter> phoneFormatters({int max = FieldLimits.phone}) => [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
  LengthLimitingTextInputFormatter(max),
];
