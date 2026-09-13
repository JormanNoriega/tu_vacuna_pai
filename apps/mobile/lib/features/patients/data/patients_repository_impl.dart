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
      if (_filled(input.secondName)) 'secondName': input.secondName,
      'lastName': input.lastName,
      if (_filled(input.secondLastName)) 'secondLastName': input.secondLastName,
      'birthDate': input.birthDate,
      'sex': input.sex,
      if (_filled(input.birthCountryId)) 'birthCountryId': input.birthCountryId,
      if (_filled(input.birthPlace)) 'birthPlace': input.birthPlace,
      if (_filled(input.migrationStatus))
        'migrationStatus': input.migrationStatus,
      if (input.gestationalAgeAtBirth != null)
        'gestationalAgeAtBirth': input.gestationalAgeAtBirth,
      if (_filled(input.vaccinationCardType))
        'vaccinationCardType': input.vaccinationCardType,
      if (input.authorizeCalls != null) 'authorizeCalls': input.authorizeCalls,
      if (input.authorizeEmail != null) 'authorizeEmail': input.authorizeEmail,
      if (input.demographics != null && !input.demographics!.isEmpty)
        'demographics': _demographicsBody(
          input.demographics!.gender,
          input.demographics!.ethnicity,
          input.demographics!.educationLevel,
          input.demographics!.sexualOrientation,
        ),
      if (input.affiliation != null && !input.affiliation!.isEmpty)
        'affiliation': _affiliationBody(
          input.affiliation!.affiliationRegime,
          input.affiliation!.insurer,
        ),
      if (input.specialConditions != null && !input.specialConditions!.isEmpty)
        'specialConditions': _specialConditionsBody(input.specialConditions!),
      if (input.userCondition != null && !input.userCondition!.isEmpty)
        'userCondition': _userConditionBody(input.userCondition!),
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
    String? educationLevel, [
    String? sexualOrientation,
  ]) => {
    if (_filled(gender)) 'gender': gender,
    if (_filled(ethnicity)) 'ethnicity': ethnicity,
    if (_filled(sexualOrientation)) 'sexualOrientation': sexualOrientation,
    if (_filled(educationLevel)) 'educationLevel': educationLevel,
  };

  Map<String, dynamic> _affiliationBody(
    String? affiliationRegime,
    String? insurer,
  ) => {
    if (_filled(affiliationRegime)) 'affiliationRegime': affiliationRegime,
    if (_filled(insurer)) 'insurer': insurer,
  };

  Map<String, dynamic> _specialConditionsBody(
    NewPatientSpecialConditions conditions,
  ) => {
    if (conditions.displaced != null) 'displaced': conditions.displaced,
    if (conditions.disabled != null) 'disabled': conditions.disabled,
    if (conditions.deceased != null) 'deceased': conditions.deceased,
    if (conditions.armedConflictVictim != null)
      'armedConflictVictim': conditions.armedConflictVictim,
    if (conditions.currentlyStudying != null)
      'currentlyStudying': conditions.currentlyStudying,
  };

  Map<String, dynamic> _userConditionBody(NewPatientUserCondition condition) =>
      {
        if (_filled(condition.userCondition))
          'userCondition': condition.userCondition,
        if (_filled(condition.lastMenstrualDate))
          'lastMenstrualDate': condition.lastMenstrualDate,
        if (condition.gestationWeeks != null)
          'gestationWeeks': condition.gestationWeeks,
        if (_filled(condition.probableDeliveryDate))
          'probableDeliveryDate': condition.probableDeliveryDate,
        if (condition.previousPregnancies != null)
          'previousPregnancies': condition.previousPregnancies,
        if (condition.hasGivenBirth != null)
          'hasGivenBirth': condition.hasGivenBirth,
        if (_filled(condition.birthPlaceDelivery))
          'birthPlaceDelivery': condition.birthPlaceDelivery,
      };

  List<Map<String, dynamic>> _contactsBody(List<NewPatientContact> contacts) =>
      [
        for (final contact in contacts)
          {
            'type': contact.type,
            'value': contact.value,
            if (_filled(contact.phoneKind)) 'phoneKind': contact.phoneKind,
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
          if (_filled(address.countryId)) 'countryId': address.countryId,
          if (_filled(address.locality)) 'locality': address.locality,
          if (_filled(address.area)) 'area': address.area,
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
        if (_filled(guardian.secondName)) 'secondName': guardian.secondName,
        if (_filled(guardian.secondLastName))
          'secondLastName': guardian.secondLastName,
        if (_filled(guardian.documentType))
          'documentType': guardian.documentType,
        if (_filled(guardian.documentNumber))
          'documentNumber': guardian.documentNumber,
        if (_filled(guardian.phone)) 'phone': guardian.phone,
        if (_filled(guardian.landline)) 'landline': guardian.landline,
        if (_filled(guardian.cellphone)) 'cellphone': guardian.cellphone,
        if (_filled(guardian.email)) 'email': guardian.email,
        if (_filled(guardian.affiliationRegime))
          'affiliationRegime': guardian.affiliationRegime,
        if (_filled(guardian.insurer)) 'insurer': guardian.insurer,
        if (_filled(guardian.ethnicity)) 'ethnicity': guardian.ethnicity,
        if (guardian.displaced != null) 'displaced': guardian.displaced,
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
        if (history.hasContraindication != null)
          'hasContraindication': history.hasContraindication,
        if (_filled(history.contraindicationDetails))
          'contraindicationDetails': history.contraindicationDetails,
        if (history.hasPreviousReaction != null)
          'hasPreviousReaction': history.hasPreviousReaction,
        if (_filled(history.reactionDetails))
          'reactionDetails': history.reactionDetails,
        if (_filled(history.historyType)) 'historyType': history.historyType,
        if (_filled(history.specialObservations))
          'specialObservations': history.specialObservations,
      },
  ];

  static bool _filled(String? value) => value != null && value.isNotEmpty;
}
