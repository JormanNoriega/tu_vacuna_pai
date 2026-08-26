import '../entities/vaccinator.dart';
import '../repositories/users_repository.dart';

class ListUsers {
  const ListUsers(this._repository);

  final UsersRepository _repository;

  Future<List<Vaccinator>> call(
    String accessToken, {
    required String institutionId,
  }) {
    return _repository.listUsersByInstitution(
      accessToken,
      institutionId: institutionId,
    );
  }
}
