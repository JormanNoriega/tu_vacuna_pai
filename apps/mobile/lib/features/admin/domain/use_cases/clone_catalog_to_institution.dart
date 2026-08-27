import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/clone_catalog_result.dart';
import '../repositories/admin_repository.dart';

/// Clona el catalogo global hacia una institucion. Online-first: requiere
/// `CATALOG_CONFIG_WRITE` y conectividad.
class CloneCatalogToInstitution {
  const CloneCatalogToInstitution(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AdminRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<CloneCatalogResult> call(
    String accessToken, {
    required OfflineAccess offline,
    required String institutionId,
    required bool includeDefaultConfig,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.catalogConfigWrite,
    );
    return _repository.cloneCatalogToInstitution(
      accessToken,
      institutionId: institutionId,
      includeDefaultConfig: includeDefaultConfig,
    );
  }
}
