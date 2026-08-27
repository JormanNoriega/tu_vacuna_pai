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
