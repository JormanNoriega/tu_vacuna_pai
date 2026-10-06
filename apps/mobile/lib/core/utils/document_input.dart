import 'package:flutter/services.dart';

import 'document_rules.dart';

/// Teclado y restricciones de entrada para el documento segun su tipo, usando
/// [documentRules] como fuente unica: solo digitos para CC/TI/RC/CN;
/// alfanumerico (letras y digitos) para el resto. El tope de longitud es el
/// `maxLength` del tipo (evita que el movil permita mas de lo que el backend
/// acepta).
///
/// La normalizacion canonica (mayusculas, sin separadores) la aplica el
/// backend; aqui solo se restringe lo que el usuario puede teclear.
bool _isAlphanumeric(String? documentType) =>
    documentRuleFor(documentType)?.digitsOnly == false;

TextInputType documentKeyboardType(String? documentType) =>
    _isAlphanumeric(documentType) ? TextInputType.text : TextInputType.number;

List<TextInputFormatter> documentInputFormatters(
  String? documentType, {
  int fallbackMax = 20,
}) {
  final rule = documentRuleFor(documentType);
  final digitsOnly = rule?.digitsOnly ?? true;
  final max = rule?.maxLength ?? fallbackMax;
  return [
    if (digitsOnly)
      FilteringTextInputFormatter.digitsOnly
    else
      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(max),
  ];
}
