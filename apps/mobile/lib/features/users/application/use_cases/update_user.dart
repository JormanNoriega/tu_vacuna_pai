import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../../domain/entities/vaccinator.dart';
import '../../domain/repositories/users_repository.dart';

/// Actualiza el estado y los roles de un usuario en una sola operacion.
///
/// Caso de uso de orquestacion (capa de aplicacion): coordina dos escrituras y
/// reconstruye el [Vaccinator] resultante. Online-first: ambas escrituras deben
/// confirmarse para considerar el cambio exitoso.
class UpdateUser {
  const UpdateUser(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final UsersRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Vaccinator> call(
    String accessToken, {
    required OfflineAccess offline,
    required String userId,
    required String status,
    required List<String> roles,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.updateUser,
    );
    return _updateStatusThenRoles(accessToken, userId, status, roles);
  }

  Future<Vaccinator> _updateStatusThenRoles(
    String accessToken,
    String userId,
    String status,
    List<String> roles,
  ) async {
    final updatedStatus = await _repository.updateStatus(
      accessToken,
      userId: userId,
      status: status,
    );
    final updatedRoles = await _repository.updateRoles(
      accessToken,
      userId: userId,
      roles: roles,
    );
    return Vaccinator(
      id: updatedStatus.id,
      email: updatedStatus.email,
      fullName: updatedStatus.fullName,
      institutionId: updatedStatus.institutionId,
      roles: updatedRoles.roles,
      status: updatedStatus.status,
      documentType: updatedStatus.documentType,
      documentNumber: updatedStatus.documentNumber,
      phone: updatedStatus.phone,
      birthDate: updatedStatus.birthDate,
      gender: updatedStatus.gender,
      professionCode: updatedStatus.professionCode,
      professionalRegistrationNumber:
          updatedStatus.professionalRegistrationNumber,
      professionalRegistrationType:
          updatedStatus.professionalRegistrationType,
    );
  }
}
