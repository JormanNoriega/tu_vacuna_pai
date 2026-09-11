import '../entities/new_patient.dart';
import '../entities/patient.dart';
import '../entities/patient_profile.dart';

/// Gestion clinica de pacientes. Las escrituras son online-first: se confirman
/// con la respuesta del servidor. La institucion se resuelve en el backend.
abstract interface class PatientsRepository {
  /// Busca pacientes por documento dentro de la institucion del actor.
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  });

  /// Crea un paciente. [operationId] es la clave de idempotencia opcional.
  Future<Patient> create(
    String accessToken, {
    required NewPatientInput input,
    String? operationId,
  });

  /// Perfil completo del paciente (identidad + tablas hijas).
  Future<PatientProfile> getById(String accessToken, String patientId);

  /// Actualiza los datos demograficos del paciente.
  Future<PatientProfile> updateDemographics(
    String accessToken,
    String patientId, {
    String? gender,
    String? ethnicity,
    String? educationLevel,
  });

  /// Actualiza contacto (telefono/correo) y direcciones del paciente.
  Future<PatientProfile> updateContact(
    String accessToken,
    String patientId, {
    required List<NewPatientContact> contacts,
    required List<NewPatientAddress> addresses,
  });

  /// Reemplaza los antecedentes medicos del paciente.
  Future<PatientProfile> updateMedicalHistories(
    String accessToken,
    String patientId,
    List<NewPatientMedicalHistory> histories,
  );
}
