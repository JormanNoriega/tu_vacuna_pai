import '../entities/vaccinator.dart';
import '../repositories/users_repository.dart';

class UpdateUserRoles {
  const UpdateUserRoles(this._repository);

  final UsersRepository _repository;

  Future<Vaccinator> call(
    String accessToken, {
    required String userId,
    required List<String> roles,
  }) {
    return _repository.updateRoles(
      accessToken,
      userId: userId,
      roles: roles,
    );
  }
}