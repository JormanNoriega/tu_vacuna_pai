import 'package:tu_vacuna_pai/features/users/domain/entities/vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/repositories/users_repository.dart';

/// Repositorio en memoria para pruebas del [UsersController].
class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository({this.failOnCreate = false});

  final bool failOnCreate;
  final List<Vaccinator> users = [];
  String? lastPassword;

  @override
  Future<Vaccinator> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) async {
    if (failOnCreate) {
      throw StateError('Fallo simulado');
    }
    lastPassword = temporaryPassword;
    final user = Vaccinator(
      id: 'user-${users.length + 1}',
      email: email,
      fullName: fullName,
      institutionId: 'inst-1',
      roles: const ['VACCINATOR'],
      status: 'ACTIVE',
    );
    users.add(user);
    return user;
  }

  @override
  Future<List<Vaccinator>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) async {
    return users.where((user) => user.institutionId == institutionId).toList();
  }
}