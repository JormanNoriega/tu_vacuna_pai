import '../entities/patient.dart';
import '../repositories/patients_repository.dart';

class SearchPatient {
  const SearchPatient(this._repository);

  final PatientsRepository _repository;

  Future<List<Patient>> call(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  }) => _repository.searchByDocument(
    accessToken,
    documentType: documentType,
    documentNumber: documentNumber,
  );
}
