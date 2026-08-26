import '../entities/institution.dart';
import '../repositories/admin_repository.dart';

class CreateInstitution {
  const CreateInstitution(this._repository);

  final AdminRepository _repository;

  Future<Institution> call(
    String accessToken, {
    required String code,
    required String name,
    int? offlineWindowHours,
  }) {
    return _repository.createInstitution(
      accessToken,
      code: code,
      name: name,
      offlineWindowHours: offlineWindowHours,
    );
  }
}