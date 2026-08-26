import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/institution.dart';
import '../repositories/admin_repository.dart';

class CreateInstitution {
  const CreateInstitution(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AdminRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Institution> call(
    String accessToken, {
    required OfflineAccess offline,
    required String code,
    required String name,
    int? offlineWindowHours,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.createInstitution,
    );
    return _repository.createInstitution(
      accessToken,
      code: code,
      name: name,
      offlineWindowHours: offlineWindowHours,
    );
  }
}
