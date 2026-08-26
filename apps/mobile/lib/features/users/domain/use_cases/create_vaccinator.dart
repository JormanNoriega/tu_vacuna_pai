import '../entities/vaccinator.dart';
import '../repositories/users_repository.dart';

class CreateVaccinator {
  const CreateVaccinator(this._repository);

  final UsersRepository _repository;

  Future<Vaccinator> call(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) {
    return _repository.createVaccinator(
      accessToken,
      email: email,
      fullName: fullName,
      temporaryPassword: temporaryPassword,
    );
  }
}