import 'document_rules.dart';

/// Normalizacion de documentos para la experiencia UX del movil. La autoridad
/// final de normalizacion y validacion es siempre el backend (Spring); aqui
/// solo se anticipa la misma regla para dar feedback inmediato al usuario.
///
/// Las reglas por tipo viven en [documentRules] (fuente unica del movil); este
/// normalizer solo las consulta.
class DocumentNormalizer {
  const DocumentNormalizer._();

  /// Forma canonica: sin espacios, puntos ni guiones, en mayusculas.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().replaceAll(RegExp(r'[.\s-]+'), '').toUpperCase();
    return s.isEmpty ? null : s;
  }

  static bool isValidForType(String? normalized, String? type) {
    if (normalized == null || type == null) return false;
    final rule = documentRuleFor(type);
    if (rule == null) return false;
    if (normalized.length < rule.minLength ||
        normalized.length > rule.maxLength) {
      return false;
    }
    final allowed = rule.digitsOnly ? RegExp(r'^\d+$') : RegExp(r'^[A-Z0-9]+$');
    return allowed.hasMatch(normalized);
  }
}
