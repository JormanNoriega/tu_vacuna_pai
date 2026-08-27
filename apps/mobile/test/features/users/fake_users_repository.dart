import 'package:tu_vacuna_pai/features/users/domain/entities/vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/repositories/users_repository.dart';

/// Repositorio en memoria para pruebas del [UsersController].
class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository({this.failOnCreate = false, this.failOnUpdate = false});

  bool failOnCreate;
  bool failOnUpdate;
  final List<Vaccinator> users = [];
  String? lastPassword;
  String? lastOperationId;

  @override
  Future<Vaccinator> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
    required String operationId,
    required String documentType,
    required String documentNumber,
    String? phone,
    String? birthDate,
    String? gender,
    required String professionCode,
    String? professionalRegistrationNumber,
    String? professionalRegistrationType,
  }) async {
    lastOperationId = operationId;
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
      documentType: documentType,
      documentNumber: documentNumber,
      phone: phone,
      birthDate: birthDate,
      gender: gender,
      professionCode: professionCode,
      professionalRegistrationNumber: professionalRegistrationNumber,
      professionalRegistrationType: professionalRegistrationType,
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

  @override
  Future<Vaccinator> updateStatus(
    String accessToken, {
    required String userId,
    required String status,
  }) async {
    if (failOnUpdate) {
      throw StateError('Fallo simulado');
    }
    final index = users.indexWhere((user) => user.id == userId);
    final current = users[index];
    final updated = Vaccinator(
      id: current.id,
      email: current.email,
      fullName: current.fullName,
      institutionId: current.institutionId,
      roles: current.roles,
      status: status,
    );
    users[index] = updated;
    return updated;
  }

  @override
  Future<Vaccinator> updateRoles(
    String accessToken, {
    required String userId,
    required List<String> roles,
  }) async {
    if (failOnUpdate) {
      throw StateError('Fallo simulado');
    }
    final index = users.indexWhere((user) => user.id == userId);
    final current = users[index];
    final updated = Vaccinator(
      id: current.id,
      email: current.email,
      fullName: current.fullName,
      institutionId: current.institutionId,
      roles: roles,
      status: current.status,
    );
    users[index] = updated;
    return updated;
  }
}
