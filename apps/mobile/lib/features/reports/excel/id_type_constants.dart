/// Catálogo de tipos de identificación colombianos y su abreviatura oficial.
class IdTypeConstants {
  static const List<String> allIdTypes = [
    'CN - Certificado de Nacido Vivo',
    'RC - Registro Civil',
    'TI - Tarjeta de Identidad',
    'CC - Cédula de Ciudadanía',
    'AS - Adulto sin Identificación',
    'MS - Menor sin Identificación',
    'CE - Cédula de Extranjería',
    'PA - Pasaporte',
    'CD - Carné Diplomático',
    'SC - Salvoconducto',
    'PE - Permiso Especial de Permanencia',
    'PPT - Permiso por Protección Temporal',
    'DE - Documento Extranjero',
  ];

  static const Map<String, String> idTypeToAbbr = {
    'CN - Certificado de Nacido Vivo': 'CN',
    'RC - Registro Civil': 'RC',
    'TI - Tarjeta de Identidad': 'TI',
    'CC - Cédula de Ciudadanía': 'CC',
    'AS - Adulto sin Identificación': 'AS',
    'MS - Menor sin Identificación': 'MS',
    'CE - Cédula de Extranjería': 'CE',
    'PA - Pasaporte': 'PA',
    'CD - Carné Diplomático': 'CD',
    'SC - Salvoconducto': 'SC',
    'PE - Permiso Especial de Permanencia': 'PE',
    'PPT - Permiso por Protección Temporal': 'PPT',
    'DE - Documento Extranjero': 'DE',
  };

  /// Convierte el tipo de identificación completo a su sigla/abreviatura estándar.
  static String toAbbreviation(String? idType) {
    if (idType == null || idType.isEmpty) return '';
    return idTypeToAbbr[idType] ?? idType;
  }
}
