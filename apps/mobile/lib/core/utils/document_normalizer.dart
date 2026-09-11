/// Normalizacion de documentos para la experiencia UX del movil. La autoridad
/// final de normalizacion y validacion es siempre el backend (Spring); aqui
/// solo se anticipa la misma regla para dar feedback inmediato al usuario.
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
    return switch (type) {
      'CC' => RegExp(r'^\d{6,10}$').hasMatch(normalized),
      'TI' ||
      'CE' ||
      'PASAPORTE' => RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(normalized),
      _ => false,
    };
  }
}
