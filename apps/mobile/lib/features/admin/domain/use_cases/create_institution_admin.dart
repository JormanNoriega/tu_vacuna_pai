import '../entities/institution_admin.dart';
import '../repositories/admin_repository.dart';

class CreateInstitutionAdmin {
  const CreateInstitutionAdmin(this._repository);

  final AdminRepository _repository;

  Future<InstitutionAdmin> call(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
  }) {
    return _repository.createInstitutionAdmin(
      accessToken,
      email: email,
      fullName: fullName,
      institutionId: institutionId,
      temporaryPassword: temporaryPassword,
    );
  }
}