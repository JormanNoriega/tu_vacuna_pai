/// Regla de formato para un tipo de documento de identidad.
///
/// Fuente unica de verdad en el movil: la consumen [DocumentInput] (formatter
/// y limite de longitud), [DocumentNormalizer] (validacion) y [FieldLimits].
/// Es el contrato espejo de `DocumentNormalizer.RULES` en el backend; los tests
/// de ambos lados garantizan que no divergan.
class DocumentRule {
  const DocumentRule({
    required this.digitsOnly,
    required this.minLength,
    required this.maxLength,
  });

  /// Si el documento solo admite digitos (CC/TI/RC/CN).
  final bool digitsOnly;

  /// Longitud minima valida.
  final int minLength;

  /// Longitud maxima valida (y tope del formatter).
  final int maxLength;
}

/// Catalogo de los 13 tipos de documento del PAI y su regla de formato.
///
/// AS/MS (sin identificacion) se tratan provisionalmente como alfanumericos
/// 4-20 porque el modelo de datos actual exige `document_number`; permitir su
/// ausencia queda como evolucion futura sujeta a definicion de negocio.
const Map<String, DocumentRule> documentRules = {
  'CC': DocumentRule(digitsOnly: true, minLength: 6, maxLength: 10),
  'TI': DocumentRule(digitsOnly: true, minLength: 6, maxLength: 11),
  'RC': DocumentRule(digitsOnly: true, minLength: 6, maxLength: 11),
  'CN': DocumentRule(digitsOnly: true, minLength: 6, maxLength: 11),
  'CE': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'PA': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'PPT': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'PE': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'SC': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'CD': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'DE': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'AS': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
  'MS': DocumentRule(digitsOnly: false, minLength: 4, maxLength: 20),
};

/// Regla del [type] (normalizado a mayusculas), o null si no esta en el
/// catalogo.
DocumentRule? documentRuleFor(String? type) {
  if (type == null) return null;
  return documentRules[type.trim().toUpperCase()];
}
