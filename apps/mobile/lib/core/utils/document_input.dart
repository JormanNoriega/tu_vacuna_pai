import 'package:flutter/services.dart';

/// Teclado y restricciones de entrada para el documento segun su tipo:
/// solo digitos para `CC`/`TI`; alfanumerico (letras y digitos) para
/// `CE`/`PASAPORTE`. En todos los casos el maximo es 10 caracteres.
///
/// La normalizacion canonica (mayusculas, sin separadores) la aplica el
/// backend; aqui solo se restringe lo que el usuario puede teclear.
bool _isAlphanumeric(String? documentType) {
  final type = (documentType ?? '').trim().toUpperCase();
  return type == 'CE' || type == 'PASAPORTE';
}

TextInputType documentKeyboardType(String? documentType) =>
    _isAlphanumeric(documentType) ? TextInputType.text : TextInputType.number;

List<TextInputFormatter> documentInputFormatters(String? documentType) => [
  if (_isAlphanumeric(documentType))
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))
  else
    FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];
