import '../entities/institution.dart';
import '../repositories/admin_repository.dart';

class ListInstitutions {
  const ListInstitutions(this._repository);

  final AdminRepository _repository;

  Future<List<Institution>> call(String accessToken) {
    return _repository.listInstitutions(accessToken);
  }
}