/// Representa una dosis configurada en el borrador de la atención (Paso 3).
class StagedDose {
  StagedDose({
    required this.vaccineId,
    required this.doseOptionId,
    required this.vaccineName,
    required this.doseDisplayName,
    required this.applicationDate,
    this.lotNumber = '',
    this.selectedLaboratoryId,
    this.laboratoryName,
    this.selectedSyringeId,
    this.syringeName,
    this.syringeLot,
    this.selectedDropperId,
    this.dropperName,
    this.diluent,
    this.pneumococcalTypeOptionId,
    this.pneumococcalTypeName,
    this.vialCount,
    this.selectedObservationId,
    this.observationName,
    this.customObservation,
    this.isCompleted = false,
  });

  final String vaccineId;
  final String doseOptionId;
  final String vaccineName;
  final String doseDisplayName;

  DateTime applicationDate;
  String lotNumber;
  String? selectedLaboratoryId;
  String? laboratoryName;
  String? selectedSyringeId;
  String? syringeName;
  String? syringeLot;
  String? selectedDropperId;
  String? dropperName;
  String? diluent;
  String? pneumococcalTypeOptionId;
  String? pneumococcalTypeName;
  int? vialCount;
  String? selectedObservationId;
  String? observationName;
  String? customObservation;

  /// Indica si los campos requeridos de la dosis ya fueron completados por el vacunador.
  bool isCompleted;

  StagedDose copyWith({
    DateTime? applicationDate,
    String? lotNumber,
    String? selectedLaboratoryId,
    String? laboratoryName,
    String? selectedSyringeId,
    String? syringeName,
    String? syringeLot,
    String? selectedDropperId,
    String? dropperName,
    String? diluent,
    String? pneumococcalTypeOptionId,
    String? pneumococcalTypeName,
    int? vialCount,
    String? selectedObservationId,
    String? observationName,
    String? customObservation,
    bool? isCompleted,
  }) => StagedDose(
    vaccineId: vaccineId,
    doseOptionId: doseOptionId,
    vaccineName: vaccineName,
    doseDisplayName: doseDisplayName,
    applicationDate: applicationDate ?? this.applicationDate,
    lotNumber: lotNumber ?? this.lotNumber,
    selectedLaboratoryId: selectedLaboratoryId ?? this.selectedLaboratoryId,
    laboratoryName: laboratoryName ?? this.laboratoryName,
    selectedSyringeId: selectedSyringeId ?? this.selectedSyringeId,
    syringeName: syringeName ?? this.syringeName,
    syringeLot: syringeLot ?? this.syringeLot,
    selectedDropperId: selectedDropperId ?? this.selectedDropperId,
    dropperName: dropperName ?? this.dropperName,
    diluent: diluent ?? this.diluent,
    pneumococcalTypeOptionId:
        pneumococcalTypeOptionId ?? this.pneumococcalTypeOptionId,
    pneumococcalTypeName: pneumococcalTypeName ?? this.pneumococcalTypeName,
    vialCount: vialCount ?? this.vialCount,
    selectedObservationId: selectedObservationId ?? this.selectedObservationId,
    observationName: observationName ?? this.observationName,
    customObservation: customObservation ?? this.customObservation,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
