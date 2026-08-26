import '../../../core/network/api_client.dart';
import '../../../core/storage/app_database.dart';
import '../domain/entities/vaccinator.dart';
import '../domain/repositories/users_repository.dart';

/// Implementacion de la gestion de usuarios de institucion. Las escrituras son
/// online-first: delegan en [ApiClient]. La lista obtenida se cachea en la base
/// local (Drift) para que el admin disponga de una referencia sin red.
class UsersRepositoryImpl implements UsersRepository {
  UsersRepositoryImpl(this._apiClient, this._database);

  final ApiClient _apiClient;
  final AppDatabase _database;

  @override
  Future<Vaccinator> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) async {
    final json = await _apiClient.createVaccinator(
      accessToken,
      email: email,
      fullName: fullName,
      temporaryPassword: temporaryPassword,
    );
    final user = Vaccinator.fromJson(json);
    await _cacheUser(user);
    return user;
  }

  @override
  Future<List<Vaccinator>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) async {
    final jsonList = await _apiClient.listUsersByInstitution(
      accessToken,
      institutionId: institutionId,
    );
    final users = jsonList.map(Vaccinator.fromJson).toList();
    for (final user in users) {
      await _cacheUser(user);
    }
    return users;
  }

  @override
  Future<Vaccinator> updateStatus(
    String accessToken, {
    required String userId,
    required String status,
  }) async {
    final json = await _apiClient.updateUserStatus(
      accessToken,
      userId: userId,
      status: status,
    );
    final user = Vaccinator.fromJson(json);
    await _cacheUser(user);
    return user;
  }

  @override
  Future<Vaccinator> updateRoles(
    String accessToken, {
    required String userId,
    required List<String> roles,
  }) async {
    final json = await _apiClient.updateUserRoles(
      accessToken,
      userId: userId,
      roles: roles,
    );
    final user = Vaccinator.fromJson(json);
    await _cacheUser(user);
    return user;
  }

  Future<void> _cacheUser(Vaccinator user) {
    return _database.upsertUser(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      institutionId: user.institutionId,
      roles: user.roles,
      status: user.status,
    );
  }
}
