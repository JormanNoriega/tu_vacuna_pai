/// Paleta de colores para los encabezados y filas del reporte Excel.
///
/// La librería `excel` de Dart utiliza el formato hexadecimal ARGB de 8 dígitos (sin `#`):
/// `AARRGGBB` donde:
/// - AA = Canal Alpha (ej. FF para 100% opaco)
/// - RR = Rojo
/// - GG = Verde
/// - BB = Azul
class ReportCategoryColors {
  const ReportCategoryColors._();

  // Colores de encabezados principales (Fila 0 - Merged)
  static const String basicData = 'FF4472C4'; // Azul intermedio
  static const String complementaryData = 'FF70AD47'; // Verde oliva/fresco
  static const String medicalHistory = 'FFFFC000'; // Amarillo dorado
  static const String userCondition = 'FFF4B084'; // Salmón suave
  static const String antecedentHistory = 'FF92D050'; // Verde claro lima
  static const String motherData = 'FFE74C3C'; // Rojo coral
  static const String caregiverData = 'FF9B59B6'; // Púrpura/violeta
  static const String vaccinationScheme = 'FF44546A'; // Azul pizarra oscuro
  static const String nurseData = 'FF3498DB'; // Azul cielo brillante
  static const String vaccines = 'FF1ABC9C'; // Turquesa / Teal

  // Colores alternados para las columnas dinámicas de Vacunas (Fila 0)
  static const String vaccineDark = 'FF1ABC9C'; // Turquesa fuerte
  static const String vaccineLight = 'FF5FD8D1'; // Turquesa claro

  // Colores para los subencabezados específicos de campos de vacunas (Fila 1)
  static const String vaccineFieldDark = 'FFB8E7E1'; // Aguamarina pastel suave
  static const String vaccineFieldLight =
      'FFDAF5F2'; // Aguamarina pastel muy claro

  // Fila 1 de encabezados de campos fijos
  static const String headerRow = 'FFE7E6E6'; // Gris claro profesional

  // Filas de datos (alternado tipo cebra)
  static const String rowEven = 'FFFFFFFF'; // Blanco
  static const String rowOdd = 'FFF2F2F2'; // Gris muy suave

  // Textos
  static const String defaultWhite =
      'FFFFFFFF'; // Blanco puro (para textos de encabezado)
  static const String textDark = 'FF000000'; // Negro puro
}
