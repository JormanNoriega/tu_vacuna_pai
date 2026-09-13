import '../../features/patients/domain/entities/new_patient.dart';

/// Construye el `payload` de cada comando del MVP a partir del estado local.
///
/// Es la unica fuente de armado de cuerpos del outbox, de modo que el camino
/// offline y el online compartan exactamente el mismo formato.
class CommandPayloads {
  const CommandPayloads._();

  static Map<String, dynamic> createPatient(NewPatientInput input) => {
    'documentType': input.documentType,
    'documentNumber': input.documentNumber,
    'firstName': input.firstName,
    'lastName': input.lastName,
    'birthDate': input.birthDate,
    'sex': input.sex,
    if (input.demographics != null && !input.demographics!.isEmpty)
      'demographics': _demographics(input.demographics!),
    if (input.contacts.isNotEmpty) 'contacts': _contacts(input.contacts),
    if (input.addresses.any((address) => !address.isEmpty))
      'addresses': _addresses(input.addresses),
    if (input.guardians.isNotEmpty) 'guardians': _guardians(input.guardians),
    if (input.medicalHistories.isNotEmpty)
      'medicalHistories': _histories(input.medicalHistories),
  };

  static Map<String, dynamic> createAttention({
    required String patientId,
    String? attentionDate,
    String? observations,
  }) => {
    'patientId': patientId,
    if (_filled(attentionDate)) 'attentionDate': attentionDate,
    if (_filled(observations)) 'observations': observations,
  };

  static Map<String, dynamic> registerAppliedDose({
    required String attentionId,
    required String vaccineId,
    required String doseOptionId,
    String? pneumococcalTypeOptionId,
    String? lotNumber,
    String? applicationDate,
    String? selectedLaboratoryId,
    String? selectedSyringeId,
    String? selectedDropperId,
    String? selectedObservationId,
  }) => {
    'attentionId': attentionId,
    'vaccineId': vaccineId,
    'doseOptionId': doseOptionId,
    if (_filled(pneumococcalTypeOptionId))
      'pneumococcalTypeOptionId': pneumococcalTypeOptionId,
    if (_filled(lotNumber)) 'lotNumber': lotNumber,
    if (_filled(applicationDate)) 'applicationDate': applicationDate,
    if (_filled(selectedLaboratoryId))
      'selectedLaboratoryId': selectedLaboratoryId,
    if (_filled(selectedSyringeId)) 'selectedSyringeId': selectedSyringeId,
    if (_filled(selectedDropperId)) 'selectedDropperId': selectedDropperId,
    if (_filled(selectedObservationId))
      'selectedObservationId': selectedObservationId,
  };

  static const Map<String, dynamic> completeAttention = {};

  static Map<String, dynamic> _demographics(NewPatientDemographic value) => {
    if (_filled(value.gender)) 'gender': value.gender,
    if (_filled(value.ethnicity)) 'ethnicity': value.ethnicity,
    if (_filled(value.educationLevel)) 'educationLevel': value.educationLevel,
  };

  static List<Map<String, dynamic>> _contacts(
    List<NewPatientContact> contacts,
  ) => [
    for (final contact in contacts)
      {
        'type': contact.type,
        'value': contact.value,
        'primary': contact.primary,
      },
  ];

  static List<Map<String, dynamic>> _addresses(
    List<NewPatientAddress> addresses,
  ) => [
    for (final address in addresses)
      if (!address.isEmpty)
        {
          if (_filled(address.street)) 'street': address.street,
          if (_filled(address.departmentId))
            'departmentId': address.departmentId,
          if (_filled(address.municipalityId))
            'municipalityId': address.municipalityId,
          'primary': address.primary,
        },
  ];

  static List<Map<String, dynamic>> _guardians(
    List<NewPatientGuardian> guardians,
  ) => [
    for (final guardian in guardians)
      {
        'relationship': guardian.relationship,
        'fullName': guardian.fullName,
        if (_filled(guardian.documentType))
          'documentType': guardian.documentType,
        if (_filled(guardian.documentNumber))
          'documentNumber': guardian.documentNumber,
        if (_filled(guardian.phone)) 'phone': guardian.phone,
      },
  ];

  static List<Map<String, dynamic>> _histories(
    List<NewPatientMedicalHistory> histories,
  ) => [
    for (final history in histories)
      {
        'condition': history.condition,
        if (_filled(history.diagnosedAt)) 'diagnosedAt': history.diagnosedAt,
        if (_filled(history.notes)) 'notes': history.notes,
      },
  ];

  static bool _filled(String? value) => value != null && value.isNotEmpty;
}
