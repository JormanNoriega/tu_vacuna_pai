import '../entities/clone_catalog_result.dart';
import '../entities/institution.dart';
import '../entities/institution_admin.dart';

/// Contrato de la administracion global (SUPER_ADMIN).
///
/// Las operaciones son online-first: solo se confirman con respuesta exitosa
/// del servidor. El access token se pasa por invocacion porque la sesion puede
/// renovarse entre llamadas.
abstract interface class AdminRepository {
  Future<Institution> createInstitution(
    String accessToken, {
    required String code,
    required String name,
    int? offlineWindowHours,
  });

  Future<List<Institution>> listInstitutions(String accessToken);

  Future<InstitutionAdmin> createInstitutionAdmin(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
    required String operationId,
  });

  Future<List<InstitutionAdmin>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  });

  Future<Institution> updateInstitutionConfig(
    String accessToken, {
    required String institutionId,
    required int offlineWindowHours,
  });

  /// Clona el catalogo global hacia una institucion (online-first).
  Future<CloneCatalogResult> cloneCatalogToInstitution(
    String accessToken, {
    required String institutionId,
    required bool includeDefaultConfig,
  });
}
