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
  });

  Future<List<InstitutionAdmin>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  });
}