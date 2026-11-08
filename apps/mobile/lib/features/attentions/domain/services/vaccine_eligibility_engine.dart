import '../../../catalogs/domain/entities/effective_catalog.dart';

/// Contexto inmutable con los datos del paciente necesarios para evaluar
/// la elegibilidad de vacunas y dosis según el esquema oficial PAI Colombia.
class PatientEligibilityContext {
  const PatientEligibilityContext({
    required this.ageInDays,
    required this.ageInMonths,
    required this.ageInYears,
    this.birthDate,
    this.attentionDate,
    this.sex,
    this.isPregnant = false,
    this.gestationalWeeks,
    this.hasSpecialCondition = false,
    this.appliedDoseKeys = const {},
  });

  final int ageInDays;
  final int ageInMonths;
  final int ageInYears;
  final DateTime? birthDate;
  final DateTime? attentionDate;
  final String? sex;
  final bool isPregnant;
  final int? gestationalWeeks;
  final bool hasSpecialCondition;
  final Set<String> appliedDoseKeys;

  /// Crea un contexto calculando con precisión la edad en días, meses y años
  /// a partir de la fecha de nacimiento y la fecha de la atención.
  factory PatientEligibilityContext.fromDates({
    required DateTime? birthDate,
    required DateTime attentionDate,
    String? sex,
    String? userCondition,
    int? gestationalWeeks,
    bool hasSpecialCondition = false,
    Set<String> appliedDoseKeys = const {},
  }) {
    if (birthDate == null) {
      return PatientEligibilityContext(
        ageInDays: 0,
        ageInMonths: 0,
        ageInYears: 0,
        birthDate: null,
        attentionDate: attentionDate,
        sex: sex,
        isPregnant: _isPregnantCondition(userCondition),
        gestationalWeeks: gestationalWeeks,
        hasSpecialCondition: hasSpecialCondition,
        appliedDoseKeys: appliedDoseKeys,
      );
    }

    final diff = attentionDate.difference(birthDate);
    final ageInDays = diff.inDays < 0 ? 0 : diff.inDays;

    int years = attentionDate.year - birthDate.year;
    int months = attentionDate.month - birthDate.month;
    int days = attentionDate.day - birthDate.day;

    if (days < 0) {
      months--;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    years = years < 0 ? 0 : years;
    months = months < 0 ? 0 : months;
    final totalMonths = (years * 12) + months;

    return PatientEligibilityContext(
      ageInDays: ageInDays,
      ageInMonths: totalMonths,
      ageInYears: years,
      birthDate: birthDate,
      attentionDate: attentionDate,
      sex: sex,
      isPregnant: _isPregnantCondition(userCondition),
      gestationalWeeks: gestationalWeeks,
      hasSpecialCondition: hasSpecialCondition,
      appliedDoseKeys: appliedDoseKeys,
    );
  }

  static bool _isPregnantCondition(String? condition) {
    if (condition == null) return false;
    final norm = condition.toUpperCase().trim();
    return norm == 'PREGNANT' ||
        norm == 'GESTANTE' ||
        norm == 'EMBARAZADA' ||
        norm.contains('GESTANT') ||
        norm.contains('EMBARAZ');
  }

  /// Retorna un texto formateado amigable de la edad (ej: "2 meses, 5 días" o "5 años").
  String get formattedAgeSummary {
    if (ageInYears >= 2) {
      return '$ageInYears años';
    }
    if (ageInMonths >= 1) {
      return '$ageInMonths meses';
    }
    return '$ageInDays días';
  }
}

/// Contrato del Patrón Specification: cada biológico implementa su regla
/// de forma aislada e inmutable (Flyweight).
abstract interface class VaccineEligibilityRule {
  bool isEligible(PatientEligibilityContext ctx);
}

// ============================================================================
// REGLAS ESPECÍFICAS POR BIOLÓGICO (ESQUEMA NACIONAL PAI COLOMBIA)
// ============================================================================

/// BCG: Dosis única al nacer (primeras 12-24h). En población indígena o rural
/// dispersa se permite captación tardía hasta los 5 años (59 meses).
class BcgRule implements VaccineEligibilityRule {
  const BcgRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    // Al nacer / primer mes
    if (ctx.ageInDays <= 30) return true;
    // Captación tardía en comunidades indígenas o condición especial hasta los 5 años
    if (ctx.hasSpecialCondition && ctx.ageInMonths < 60) return true;
    return false;
  }
}

/// Hepatitis B: Recién nacido (primeras 12 horas).
class HepatitisBRecienNacidoRule implements VaccineEligibilityRule {
  const HepatitisBRecienNacidoRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    // Recién nacido primeras semanas o esquemas iniciales antes de 1 año
    return ctx.ageInMonths < 12;
  }
}

/// Polio VIP (Inactivado) y Polio Oral (OPV):
/// 2 meses (1ª), 4 meses (2ª), 6 meses (3ª), 18 meses (1er refuerzo), 5 años (2do refuerzo).
class PolioRule implements VaccineEligibilityRule {
  const PolioRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    // A partir de los 2 meses hasta los 6 años (72 meses)
    return ctx.ageInMonths >= 2 && ctx.ageInMonths <= 72;
  }
}

/// Pentavalente (DPT + HB + Hib) y Hexavalente:
/// 2 meses (1ª), 4 meses (2ª), 6 meses (3ª) y 1er refuerzo a los 18 meses.
/// Hasta los 4 años 11 meses 29 días (< 60 meses).
class PentavalenteRule implements VaccineEligibilityRule {
  const PentavalenteRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInMonths >= 2 && ctx.ageInMonths < 60;
  }
}

/// Rotavirus:
/// - 1ª dosis: estrictamente entre 2 meses (60 días) y 3 meses 21 días (111 días).
/// - 2ª dosis: hasta los 11 meses 29 días, EXCLUSIVAMENTE si ya cuenta con 1ª dosis.
class RotavirusRule implements VaccineEligibilityRule {
  const RotavirusRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    final hasDose1 = ctx.appliedDoseKeys.any(
      (k) =>
          k.toLowerCase().contains('rotavirus') &&
          (k.contains('1') || k.contains('primera')),
    );

    if (!hasDose1) {
      // 1ra dosis estricta: entre 60 y 111 días (3 meses y 21 días)
      return ctx.ageInDays >= 60 && ctx.ageInDays <= 111;
    } else {
      // 2da dosis: hasta los 11 meses y 29 días
      return ctx.ageInMonths < 12;
    }
  }
}

/// Neumococo Conjugada:
/// 2 meses (1ª), 4 meses (2ª) y refuerzo a los 12 meses (hasta 23 meses).
class NeumococoRule implements VaccineEligibilityRule {
  const NeumococoRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInMonths >= 2 && ctx.ageInMonths < 24;
  }
}

/// Triple Viral (SRP):
/// 1ª dosis a los 12 meses, refuerzo a los 18 meses.
/// Se garantiza cobertura hasta los 10 años 11 meses 29 días (< 132 meses).
class TripleViralRule implements VaccineEligibilityRule {
  const TripleViralRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInMonths >= 12 && ctx.ageInMonths < 132;
  }
}

/// Varicela:
/// 1ª dosis a los 12 meses, refuerzo a los 5 años.
/// Cohorte garantizada a nacidos desde el 1 de julio de 2014.
class VaricelaRule implements VaccineEligibilityRule {
  const VaricelaRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    if (ctx.ageInMonths < 12) return false;
    // Si conocemos la fecha de nacimiento, verificar cohorte (nacidos >= 01/julio/2014)
    if (ctx.birthDate != null &&
        ctx.birthDate!.isBefore(DateTime(2014, 7, 1))) {
      return false;
    }
    // Habilitado hasta los 10 años
    return ctx.ageInYears <= 10;
  }
}

/// Hepatitis A Pediátrica:
/// Dosis única a los 12 meses. Cohorte nacida desde el 1 de enero de 2012.
class HepatitisAPediatricaRule implements VaccineEligibilityRule {
  const HepatitisAPediatricaRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    if (ctx.ageInMonths < 12) return false;
    if (ctx.birthDate != null &&
        ctx.birthDate!.isBefore(DateTime(2012, 1, 1))) {
      return false;
    }
    return ctx.ageInYears <= 12;
  }
}

/// Fiebre Amarilla:
/// Dosis única a los 18 meses. Población susceptible 1 a 14 años, o viajeros /
/// zonas de riesgo hasta 59 años.
class FiebreAmarillaRule implements VaccineEligibilityRule {
  const FiebreAmarillaRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInMonths >= 12 && ctx.ageInYears < 60;
  }
}

/// DPT Pediátrico / Refuerzos:
/// 1er refuerzo a los 18 meses, 2do refuerzo a los 5 años (hasta los 7 años / 84 meses).
class DptRule implements VaccineEligibilityRule {
  const DptRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInMonths >= 18 && ctx.ageInMonths <= 84;
  }
}

/// Virus del Papiloma Humano (VPH):
/// Rango oficial: 9 a 17 años cumplidos (niños y niñas).
class VphRule implements VaccineEligibilityRule {
  const VphRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInYears >= 9 && ctx.ageInYears <= 17;
  }
}

/// Td Adulto (Toxoide Tetánico Diftérico):
/// Rango: 10 a 49 años (Mujeres en Edad Fértil y población general).
class TdAdultoRule implements VaccineEligibilityRule {
  const TdAdultoRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    return ctx.ageInYears >= 10 && ctx.ageInYears <= 49;
  }
}

/// dTpa Adulto (TdaP Acelular Gestante):
/// Dosis única en cada embarazo a partir de la semana 20 (recomendado sem 26-36).
class DtpaAdultoRule implements VaccineEligibilityRule {
  const DtpaAdultoRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    if (!ctx.isPregnant) return false;
    final weeks = ctx.gestationalWeeks ?? 0;
    return weeks >= 20;
  }
}

/// Influenza Estacional:
/// - Pediátrica: 6 a 23 meses.
/// - Gestantes: a partir de la semana 14 de embarazo.
/// - Adultos mayores: a partir de los 60 años cumplidos.
class InfluenzaRule implements VaccineEligibilityRule {
  const InfluenzaRule();

  @override
  bool isEligible(PatientEligibilityContext ctx) {
    // 1. Pediátrica: 6 a 23 meses
    if (ctx.ageInMonths >= 6 && ctx.ageInMonths < 24) return true;
    // 2. Gestantes a partir de sem 14
    if (ctx.isPregnant && (ctx.gestationalWeeks ?? 0) >= 14) return true;
    // 3. Adulto Mayor: 60+ años
    if (ctx.ageInYears >= 60) return true;
    return false;
  }
}

// ============================================================================
// MOTOR CENTRAL DE DESPACHO O(1) (HASH DISPATCHER)
// ============================================================================

/// Motor de Reglas de Elegibilidad de Vacunas y Dosis (PAI Colombia).
class VaccineEligibilityEngine {
  VaccineEligibilityEngine._();

  static const Map<String, VaccineEligibilityRule> _rulesByCode = {
    'bcg': BcgRule(),
    'hepatitis_b': HepatitisBRecienNacidoRule(),
    'polio_ipv': PolioRule(),
    'polio_oral': PolioRule(),
    'pentavalente': PentavalenteRule(),
    'hexavalente': PentavalenteRule(),
    'rotavirus': RotavirusRule(),
    'neumococo': NeumococoRule(),
    'srp': TripleViralRule(),
    'varicela': VaricelaRule(),
    'hepatitis_a_pediatrica': HepatitisAPediatricaRule(),
    'fiebre_amarilla': FiebreAmarillaRule(),
    'dpt': DptRule(),
    'dtpa_pediatrico': DptRule(),
    'td_pediatrico': DptRule(),
    'vph': VphRule(),
    'td_adulto': TdAdultoRule(),
    'dtpa_adulto': DtpaAdultoRule(),
    'influenza': InfluenzaRule(),
  };

  /// Evalúa en tiempo O(1) si la vacuna es elegible para el paciente.
  static bool isEligible(
    EffectiveVaccine vaccine,
    PatientEligibilityContext ctx,
  ) {
    final code = vaccine.code.toLowerCase().trim();
    final rule = _rulesByCode[code];
    if (rule != null) {
      return rule.isEligible(ctx);
    }

    // Biológicos sin regla especial registrada se admiten por defecto
    return true;
  }

  /// Evalúa si una dosis específica es elegible considerando prerrequisitos
  /// clínicos (ejemplo: Rotavirus 2da dosis requiere 1ra dosis previa).
  static bool isDoseEligible(
    EffectiveVaccine vaccine,
    EffectiveOption doseOption,
    PatientEligibilityContext ctx,
  ) {
    final vCode = vaccine.code.toLowerCase().trim();
    final dName = doseOption.displayName.toLowerCase().trim();

    // Regla crítica Rotavirus
    if (vCode == 'rotavirus') {
      final isSecondDose = dName.contains('2') || dName.contains('segunda');
      if (isSecondDose) {
        final hasDose1 = ctx.appliedDoseKeys.any(
          (k) =>
              k.toLowerCase().contains('rotavirus') &&
              (k.contains('1') || k.contains('primera')),
        );
        if (!hasDose1) return false;
      }
    }

    return true;
  }

  /// Retorna un motivo clínico descriptivo si una dosis no es elegible.
  static String? getDoseIneligibilityWarning(
    EffectiveVaccine vaccine,
    EffectiveOption doseOption,
    PatientEligibilityContext ctx,
  ) {
    final vCode = vaccine.code.toLowerCase().trim();
    final dName = doseOption.displayName.toLowerCase().trim();

    if (vCode == 'rotavirus') {
      final isSecondDose = dName.contains('2') || dName.contains('segunda');
      if (isSecondDose) {
        final hasDose1 = ctx.appliedDoseKeys.any(
          (k) =>
              k.toLowerCase().contains('rotavirus') &&
              (k.contains('1') || k.contains('primera')),
        );
        if (!hasDose1) {
          return 'No se puede aplicar la 2ª dosis de Rotavirus sin antecedente registrado de 1ª dosis.';
        }
      }
    }

    return null;
  }
}
