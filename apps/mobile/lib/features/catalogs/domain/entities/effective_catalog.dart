/// Opcion del catalogo efectivo (dosis, tipo de neumococo u operativa).
class EffectiveOption {
  const EffectiveOption({
    required this.id,
    required this.fieldType,
    required this.value,
    required this.displayName,
    required this.sortOrder,
    required this.isDefault,
  });

  final String id;
  final String fieldType;
  final String value;
  final String displayName;
  final int sortOrder;
  final bool isDefault;

  factory EffectiveOption.fromJson(Map<String, dynamic> json) =>
      EffectiveOption(
        id: json['id'].toString(),
        fieldType: json['fieldType'] as String,
        value: json['value'] as String,
        displayName: json['displayName'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isDefault:
            json['default'] as bool? ?? json['isDefault'] as bool? ?? false,
      );
}

/// Vacuna habilitada en la institucion del actor, con sus opciones vigentes.
class EffectiveVaccine {
  const EffectiveVaccine({
    required this.vaccineId,
    required this.name,
    required this.code,
    required this.category,
    required this.maxDoses,
    required this.version,
    required this.doses,
    required this.pneumococcalTypes,
    required this.operationalOptions,
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

  final String vaccineId;
  final String name;
  final String code;
  final String category;
  final int maxDoses;
  final int version;
  final List<EffectiveOption> doses;
  final List<EffectiveOption> pneumococcalTypes;
  final List<EffectiveOption> operationalOptions;
  final bool hasLaboratory;
  final bool hasLot;
  final bool hasSyringe;
  final bool hasSyringeLot;
  final bool hasDiluent;
  final bool hasDropper;
  final bool hasPneumococcalType;
  final bool hasVialCount;
  final bool hasObservation;

  factory EffectiveVaccine.fromJson(Map<String, dynamic> json) =>
      EffectiveVaccine(
        vaccineId: json['vaccineId'].toString(),
        name: json['name'] as String,
        code: json['code'] as String,
        category: json['category'] as String? ?? '',
        maxDoses: (json['maxDoses'] as num?)?.toInt() ?? 1,
        version: (json['version'] as num?)?.toInt() ?? 0,
        doses: _options(json['doses']),
        pneumococcalTypes: _options(json['pneumococcalTypes']),
        operationalOptions: _options(json['operationalOptions']),
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

  static List<EffectiveOption> _options(dynamic list) =>
      ((list as List<dynamic>?) ?? const [])
          .map((item) => EffectiveOption.fromJson(item as Map<String, dynamic>))
          .toList();
}
