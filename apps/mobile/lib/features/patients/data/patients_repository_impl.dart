import '../../../core/network/api_client.dart';
import '../domain/entities/new_patient.dart';
import '../domain/entities/patient.dart';
import '../domain/entities/patient_profile.dart';
import '../domain/repositories/patients_repository.dart';

class PatientsRepositoryImpl implements PatientsRepository {
  PatientsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  }) async {
    final jsonList = await _apiClient.searchPatients(
      accessToken,
      documentType: documentType,
      documentNumber: documentNumber,
    );
    return jsonList.map(Patient.fromJson).toList();
  }

  @override
  Future<Patient> create(
    String accessToken, {
    required NewPatientInput input,
    String? operationId,
  }) async {
    final body = <String, dynamic>{
      'documentType': input.documentType,
      'documentNumber': input.documentNumber,
      'firstName': input.firstName,
      'lastName': input.lastName,
      'birthDate': input.birthDate,
      'sex': input.sex,
      if (input.demographics != null && !input.demographics!.isEmpty)
        'demographics': _demographicsBody(
          input.demographics!.gender,
          input.demographics!.ethnicity,
          input.demographics!.educationLevel,
        ),
      if (input.contacts.isNotEmpty) 'contacts': _contactsBody(input.contacts),
      if (input.addresses.any((address) => !address.isEmpty))
        'addresses': _addressesBody(input.addresses),
      if (input.guardians.isNotEmpty)
        'guardians': _guardiansBody(input.guardians),
      if (input.medicalHistories.isNotEmpty)
        'medicalHistories': _historiesBody(input.medicalHistories),
    };
    final json = await _apiClient.createPatient(
      accessToken,
      body,
      operationId: operationId,
    );
    return Patient.fromJson(json);
  }

  @override
  Future<PatientProfile> getById(String accessToken, String patientId) async =>
      PatientProfile.fromJson(
        await _apiClient.getPatient(accessToken, patientId),
      );

  @override
  Future<PatientProfile> updateDemographics(
    String accessToken,
    String patientId, {
    String? gender,
    String? ethnicity,
    String? educationLevel,
  }) async => PatientProfile.fromJson(
    await _apiClient.updatePatientDemographics(
      accessToken,
      patientId,
      _demographicsBody(gender, ethnicity, educationLevel),
    ),
  );

  @override
  Future<PatientProfile> updateContact(
    String accessToken,
    String patientId, {
    required List<NewPatientContact> contacts,
    required List<NewPatientAddress> addresses,
  }) async => PatientProfile.fromJson(
    await _apiClient.updatePatientContact(accessToken, patientId, {
      'contacts': _contactsBody(contacts),
      'addresses': _addressesBody(addresses),
    }),
  );

  @override
  Future<PatientProfile> updateMedicalHistories(
    String accessToken,
    String patientId,
    List<NewPatientMedicalHistory> histories,
  ) async => PatientProfile.fromJson(
    await _apiClient.updatePatientMedicalHistories(accessToken, patientId, {
      'medicalHistories': _historiesBody(histories),
    }),
  );

  // ---------- body builders ----------

  Map<String, dynamic> _demographicsBody(
    String? gender,
    String? ethnicity,
    String? educationLevel,
  ) => {
    if (_filled(gender)) 'gender': gender,
    if (_filled(ethnicity)) 'ethnicity': ethnicity,
    if (_filled(educationLevel)) 'educationLevel': educationLevel,
  };

  List<Map<String, dynamic>> _contactsBody(List<NewPatientContact> contacts) =>
      [
        for (final contact in contacts)
          {
            'type': contact.type,
            'value': contact.value,
            'primary': contact.primary,
          },
      ];

  List<Map<String, dynamic>> _addressesBody(
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

  List<Map<String, dynamic>> _guardiansBody(
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

  List<Map<String, dynamic>> _historiesBody(
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
