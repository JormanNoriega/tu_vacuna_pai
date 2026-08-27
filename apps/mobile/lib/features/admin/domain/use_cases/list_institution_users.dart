import '../entities/institution_admin.dart';
import '../repositories/admin_repository.dart';

/// Lista los usuarios administrativos de una institucion.
class ListInstitutionUsers {
  ListInstitutionUsers(this._repository);

  final AdminRepository _repository;

  Future<List<InstitutionAdmin>> call(
    String token, {
    required String institutionId,
  }) => _repository.listUsersByInstitution(token, institutionId: institutionId);
}
