class Vaccine {
  const Vaccine({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.maxDoses,
    this.minAgeMonths,
    this.maxAgeMonths,
    required this.active,
    required this.version,
    this.hasLaboratory = false,
    this.hasLot = true,
    this.hasSyringe = false,
    this.hasSyringeLot = false,
    this.hasDiluent = false,
    this.hasDropper = false,
    this.hasPneumococcalType = false,
    this.hasVialCount = false,
    this.hasObservation = false,
  });
  final String id;
  final String name;
  final String code;
  final String category;
  final int maxDoses;
  final int? minAgeMonths;
  final int? maxAgeMonths;
  final bool active;
  final int version;
  final bool hasLaboratory;
  final bool hasLot;
  final bool hasSyringe;
  final bool hasSyringeLot;
  final bool hasDiluent;
  final bool hasDropper;
  final bool hasPneumococcalType;
  final bool hasVialCount;
  final bool hasObservation;
  String get ageRange => minAgeMonths == null && maxAgeMonths == null
      ? 'Edad no definida'
      : '${minAgeMonths ?? 0}-${maxAgeMonths ?? '+'} meses';
  factory Vaccine.fromJson(Map<String, dynamic> json) => Vaccine(
    id: json['id'].toString(),
    name: json['name'] as String,
    code: json['code'] as String,
    category: json['category'] as String,
    maxDoses: (json['maxDoses'] as num).toInt(),
    minAgeMonths: (json['minAgeMonths'] as num?)?.toInt(),
    maxAgeMonths: (json['maxAgeMonths'] as num?)?.toInt(),
    active: json['active'] as bool? ?? true,
    version: (json['version'] as num?)?.toInt() ?? 0,
    hasLaboratory: json['hasLaboratory'] as bool? ?? false,
    hasLot: json['hasLot'] as bool? ?? true,
    hasSyringe: json['hasSyringe'] as bool? ?? false,
    hasSyringeLot: json['hasSyringeLot'] as bool? ?? false,
    hasDiluent: json['hasDiluent'] as bool? ?? false,
    hasDropper: json['hasDropper'] as bool? ?? false,
    hasPneumococcalType: json['hasPneumococcalType'] as bool? ?? false,
    hasVialCount: json['hasVialCount'] as bool? ?? false,
    hasObservation: json['hasObservation'] as bool? ?? false,
  );
}

class VaccineOption {
  const VaccineOption({
    required this.id,
    required this.vaccineId,
    this.institutionId,
    required this.fieldType,
    required this.value,
    required this.displayName,
    required this.sortOrder,
    required this.isDefault,
    required this.isActive,
    this.sourceTemplateId,
    required this.version,
  });
  final String id;
  final String vaccineId;
  final String? institutionId;
  final String fieldType;
  final String value;
  final String displayName;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final String? sourceTemplateId;
  final int version;
  factory VaccineOption.fromJson(Map<String, dynamic> json) => VaccineOption(
    id: json['id'].toString(),
    vaccineId: json['vaccineId'].toString(),
    institutionId: json['institutionId']?.toString(),
    fieldType: json['fieldType'] as String,
    value: json['value'] as String,
    displayName: json['displayName'] as String,
    sortOrder: (json['sortOrder'] as num).toInt(),
    isDefault: json['default'] as bool? ?? json['isDefault'] as bool? ?? false,
    isActive: json['active'] as bool? ?? json['isActive'] as bool? ?? true,
    sourceTemplateId: json['sourceTemplateId']?.toString(),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );
}

class VaccineOptionTemplate extends VaccineOption {
  const VaccineOptionTemplate({
    required super.id,
    required super.vaccineId,
    required super.fieldType,
    required super.value,
    required super.displayName,
    required super.sortOrder,
    required super.isDefault,
    required super.version,
  }) : super(isActive: true);
}

class InstitutionVaccine {
  const InstitutionVaccine({
    this.id,
    required this.institutionId,
    required this.vaccineId,
    required this.name,
    required this.code,
    required this.category,
    required this.enabled,
    required this.version,
  });
  final String? id;
  final String institutionId;
  final String vaccineId;
  final String name;
  final String code;
  final String category;
  final bool enabled;
  final int version;

  factory InstitutionVaccine.fromJson(Map<String, dynamic> json) =>
      InstitutionVaccine(
        id: json['id']?.toString(),
        institutionId: json['institutionId'].toString(),
        vaccineId: json['vaccineId'].toString(),
        name: json['name'] as String,
        code: json['code'] as String,
        category: json['category'] as String,
        enabled: json['enabled'] as bool? ?? false,
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
}

class InstitutionVaccineOption extends VaccineOption {
  const InstitutionVaccineOption({
    required super.id,
    required super.vaccineId,
    required super.institutionId,
    required super.fieldType,
    required super.value,
    required super.displayName,
    required super.sortOrder,
    required super.isDefault,
    required super.isActive,
    super.sourceTemplateId,
    required super.version,
  });
}

Map<String, dynamic> optionPayload({
  required String fieldType,
  required String value,
  required bool isDefault,
  int sortOrder = 0,
  int version = 0,
}) => {
  'fieldType': fieldType,
  'value': value,
  'displayName': value,
  'sortOrder': sortOrder,
  'isDefault': isDefault,
  'isActive': true,
  'version': version,
};

/// Opcion de un catalogo de referencia (lista cerrada del backend).
class ReferenceOption {
  const ReferenceOption({
    required this.code,
    required this.label,
    required this.sortOrder,
  });

  final String code;
  final String label;
  final int sortOrder;

  factory ReferenceOption.fromJson(Map<String, dynamic> json) =>
      ReferenceOption(
        code: json['code'] as String,
        label: json['label'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

/// Catalogo de referencia (`document_type`, `sex`, `gender`, ...). Agrupa una
/// lista cerrada de opciones usada por los dropdowns del wizard.
class ReferenceCatalog {
  const ReferenceCatalog({
    required this.code,
    required this.name,
    required this.options,
  });

  final String code;
  final String name;
  final List<ReferenceOption> options;

  factory ReferenceCatalog.fromJson(Map<String, dynamic> json) =>
      ReferenceCatalog(
        code: json['code'] as String,
        name: json['name'] as String? ?? json['code'] as String,
        options: (json['options'] as List<dynamic>? ?? [])
            .map(
              (item) => ReferenceOption.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

/// Tipos de identificacion del formato PAI. Fallback local (mismos codigos del
/// catalogo `document_type` del backend) para cuando el catalogo no ha cargado.
const List<ReferenceOption> documentTypeFallback = [
  ReferenceOption(
    code: 'CN',
    label: 'Certificado de Nacido Vivo',
    sortOrder: 1,
  ),
  ReferenceOption(code: 'RC', label: 'Registro Civil', sortOrder: 2),
  ReferenceOption(code: 'TI', label: 'Tarjeta de Identidad', sortOrder: 3),
  ReferenceOption(code: 'CC', label: 'Cedula de Ciudadania', sortOrder: 4),
  ReferenceOption(code: 'AS', label: 'Adulto sin Identificacion', sortOrder: 5),
  ReferenceOption(code: 'MS', label: 'Menor sin Identificacion', sortOrder: 6),
  ReferenceOption(code: 'CE', label: 'Cedula de Extranjeria', sortOrder: 7),
  ReferenceOption(code: 'PA', label: 'Pasaporte', sortOrder: 8),
  ReferenceOption(code: 'CD', label: 'Carne Diplomatico', sortOrder: 9),
  ReferenceOption(code: 'SC', label: 'Salvoconducto', sortOrder: 10),
  ReferenceOption(
    code: 'PE',
    label: 'Permiso Especial de Permanencia',
    sortOrder: 11,
  ),
  ReferenceOption(
    code: 'PPT',
    label: 'Permiso por Proteccion Temporal',
    sortOrder: 12,
  ),
  ReferenceOption(code: 'DE', label: 'Documento Extranjero', sortOrder: 13),
];

/// Aseguradora en salud (EPS) del catalogo global. `regime` indica los
/// regimenes que atiende la entidad: `CONTRIBUTIVO`, `SUBSIDIADO` o `AMBOS`.
class HealthInsurer {
  const HealthInsurer({
    required this.id,
    required this.nit,
    required this.name,
    required this.regime,
    this.code,
  });

  final String id;
  final String nit;
  final String name;
  final String regime;
  final String? code;

  /// Sirve para regimen contributivo (`AMBOS` incluido).
  bool get servesContributive => regime == 'CONTRIBUTIVO' || regime == 'AMBOS';

  /// Sirve para regimen subsidiado (`AMBOS` incluido).
  bool get servesSubsidized => regime == 'SUBSIDIADO' || regime == 'AMBOS';

  factory HealthInsurer.fromJson(Map<String, dynamic> json) => HealthInsurer(
    id: json['id'].toString(),
    nit: json['nit'] as String? ?? '',
    name: json['name'] as String? ?? '',
    regime: json['regime'] as String? ?? '',
    code: json['code'] as String?,
  );
}
