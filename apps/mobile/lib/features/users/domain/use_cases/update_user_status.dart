import '../entities/vaccinator.dart';
import '../repositories/users_repository.dart';

class UpdateUserStatus {
  const UpdateUserStatus(this._repository);

  final UsersRepository _repository;

  Future<Vaccinator> call(
    String accessToken, {
    required String userId,
    required String status,
  }) {
    return _repository.updateStatus(
      accessToken,
      userId: userId,
      status: status,
    );
  }
}