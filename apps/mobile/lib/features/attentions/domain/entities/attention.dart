/// Dosis aplicada con su snapshot de catalogo (append-only).
class AppliedDose {
  const AppliedDose({
    required this.id,
    required this.attentionId,
    required this.vaccineId,
    required this.vaccineNameSnapshot,
    required this.vaccineCodeSnapshot,
    required this.doseLabelSnapshot,
    required this.status,
    this.doseValueSnapshot,
    this.pneumococcalTypeSnapshot,
    this.lotNumber,
    this.applicationDate,
    this.cancelledReason,
    this.catalogVersion = 0,
  });

  final String id;
  final String attentionId;
  final String vaccineId;
  final String vaccineNameSnapshot;
  final String vaccineCodeSnapshot;
  final String doseLabelSnapshot;
  final String status;
  final String? doseValueSnapshot;
  final String? pneumococcalTypeSnapshot;
  final String? lotNumber;
  final DateTime? applicationDate;
  final String? cancelledReason;
  final int catalogVersion;

  bool get isCancelled => status == 'CANCELLED';

  factory AppliedDose.fromJson(Map<String, dynamic> json) => AppliedDose(
    id: json['id'].toString(),
    attentionId: json['attentionId'].toString(),
    vaccineId: json['vaccineId'].toString(),
    vaccineNameSnapshot: json['vaccineNameSnapshot'] as String? ?? '',
    vaccineCodeSnapshot: json['vaccineCodeSnapshot'] as String? ?? '',
    doseLabelSnapshot: json['doseLabelSnapshot'] as String? ?? '',
    status: json['status'] as String? ?? 'REGISTERED',
    doseValueSnapshot: json['doseValueSnapshot'] as String?,
    pneumococcalTypeSnapshot: json['pneumococcalTypeSnapshot'] as String?,
    lotNumber: json['lotNumber'] as String?,
    applicationDate: json['applicationDate'] == null
        ? null
        : DateTime.tryParse(json['applicationDate'] as String),
    cancelledReason: json['cancelledReason'] as String?,
    catalogVersion: (json['catalogVersion'] as num?)?.toInt() ?? 0,
  );
}

/// Atencion de vacunacion con sus dosis aplicadas.
class Attention {
  const Attention({
    required this.id,
    required this.patientId,
    required this.professionalId,
    required this.status,
    required this.version,
    required this.doses,
    this.attentionDate,
    this.consecutive,
    this.observations,
    this.completeScheme = false,
    this.paiwebRegistered = false,
    this.paiwebNotRegisteredReason,
  });

  final String id;
  final String patientId;
  final String professionalId;
  final String status;
  final int version;
  final List<AppliedDose> doses;
  final DateTime? attentionDate;
  final int? consecutive;
  final String? observations;
  final bool completeScheme;
  final bool paiwebRegistered;
  final String? paiwebNotRegisteredReason;

  bool get isEditable => status == 'DRAFT' || status == 'IN_PROGRESS';

  String get statusLabel => switch (status) {
    'DRAFT' => 'Borrador',
    'IN_PROGRESS' => 'En curso',
    'COMPLETED' => 'Completada',
    'CANCELLED' => 'Anulada',
    _ => status,
  };

  factory Attention.fromJson(Map<String, dynamic> json) => Attention(
    id: json['id'].toString(),
    patientId: json['patientId'].toString(),
    professionalId: json['professionalId'].toString(),
    status: json['status'] as String? ?? 'DRAFT',
    version: (json['version'] as num?)?.toInt() ?? 0,
    doses: ((json['doses'] as List<dynamic>?) ?? const [])
        .map((item) => AppliedDose.fromJson(item as Map<String, dynamic>))
        .toList(),
    attentionDate: json['attentionDate'] == null
        ? null
        : DateTime.tryParse(json['attentionDate'] as String),
    consecutive: (json['consecutive'] as num?)?.toInt(),
    observations: json['observations'] as String?,
    completeScheme: json['completeScheme'] as bool? ?? false,
    paiwebRegistered: json['paiwebRegistered'] as bool? ?? false,
    paiwebNotRegisteredReason: json['paiwebNotRegisteredReason'] as String?,
  );
}
