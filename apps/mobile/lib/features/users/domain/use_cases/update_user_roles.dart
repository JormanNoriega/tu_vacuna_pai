import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/vaccinator.dart';
import '../repositories/users_repository.dart';

class UpdateUserRoles {
  const UpdateUserRoles(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final UsersRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Vaccinator> call(
    String accessToken, {
    required OfflineAccess offline,
    required String userId,
    required List<String> roles,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.updateUser,
    );
    return _repository.updateRoles(accessToken, userId: userId, roles: roles);
  }
}
