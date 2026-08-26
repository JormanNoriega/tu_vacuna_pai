import '../../../core/network/api_client.dart';
import '../domain/entities/institution.dart';
import '../domain/entities/institution_admin.dart';
import '../domain/repositories/admin_repository.dart';

/// Implementacion HTTP del repositorio de administracion. Todas las
/// operaciones son online-first: delegan en [ApiClient] y no tocan SQLite.
class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Institution> createInstitution(
    String accessToken, {
    required String code,
    required String name,
    int? offlineWindowHours,
  }) async {
    final json = await _apiClient.createInstitution(
      accessToken,
      code: code,
      name: name,
      offlineWindowHours: offlineWindowHours,
    );
    return Institution.fromJson(json);
  }

  @override
  Future<List<Institution>> listInstitutions(String accessToken) async {
    final jsonList = await _apiClient.listInstitutions(accessToken);
    return jsonList.map(Institution.fromJson).toList();
  }

  @override
  Future<InstitutionAdmin> createInstitutionAdmin(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
  }) async {
    final json = await _apiClient.createInstitutionAdmin(
      accessToken,
      email: email,
      fullName: fullName,
      institutionId: institutionId,
      temporaryPassword: temporaryPassword,
    );
    return InstitutionAdmin.fromJson(json);
  }

  @override
  Future<List<InstitutionAdmin>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) async {
    final jsonList = await _apiClient.listUsersByInstitution(
      accessToken,
      institutionId: institutionId,
    );
    return jsonList.map(InstitutionAdmin.fromJson).toList();
  }

  @override
  Future<Institution> updateInstitutionConfig(
    String accessToken, {
    required String institutionId,
    required int offlineWindowHours,
  }) async {
    final json = await _apiClient.updateInstitutionConfig(
      accessToken,
      institutionId: institutionId,
      offlineWindowHours: offlineWindowHours,
    );
    return Institution.fromJson(json);
  }
}
