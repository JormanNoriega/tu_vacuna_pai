/// Catálogo de tipos de carnet de vacunación soportados por el sistema.
enum CarnetType {
  carneVacunacionInfantil,
  carneVacunacionAdultos,
  carneVacunacionInternacional,
  tarjetasUnificadasVacunacionAdultos,
  tarjetasUnificadasVacunacionNinos,
}

extension CarnetTypeX on CarnetType {
  /// Representación legible para mostrar en reportes (en español, mayúsculas).
  String get display {
    switch (this) {
      case CarnetType.carneVacunacionInfantil:
        return 'CARNÉ DE VACUNACIÓN INFANTIL';
      case CarnetType.carneVacunacionAdultos:
        return 'CARNÉ/CERTIFICADO DE VACUNACIÓN DE ADULTOS';
      case CarnetType.carneVacunacionInternacional:
        return 'CARNÉ/CERTIFICADO INTERNACIONAL DE VACUNACIÓN';
      case CarnetType.tarjetasUnificadasVacunacionAdultos:
        return 'TARJETAS UNIFICADAS DE VACUNACIÓN - TUV ADULTOS';
      case CarnetType.tarjetasUnificadasVacunacionNinos:
        return 'TARJETAS UNIFICADAS DE VACUNACIÓN - TUV NIÑOS';
    }
  }
}

/// Formatea un identificador de tipo de carnet a su etiqueta oficial legible.
String formatCarnetType(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parsed = CarnetType.values
      .where((c) => c.name == raw)
      .cast<CarnetType?>()
      .firstWhere((_) => true, orElse: () => null);
  return parsed?.display ?? raw.toUpperCase();
}
