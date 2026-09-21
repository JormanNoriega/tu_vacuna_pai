import 'package:flutter/services.dart';

/// Limites de longitud coherentes con las validaciones `@Size` del backend.
abstract final class FieldLimits {
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
