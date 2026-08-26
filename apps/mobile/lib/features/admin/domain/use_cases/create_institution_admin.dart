import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/institution_admin.dart';
import '../repositories/admin_repository.dart';

class CreateInstitutionAdmin {
  const CreateInstitutionAdmin(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AdminRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<InstitutionAdmin> call(
    String accessToken, {
    required OfflineAccess offline,
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.createInstitutionAdmin,
    );
    return _repository.createInstitutionAdmin(
      accessToken,
      email: email,
      fullName: fullName,
      institutionId: institutionId,
      temporaryPassword: temporaryPassword,
    );
  }
}
