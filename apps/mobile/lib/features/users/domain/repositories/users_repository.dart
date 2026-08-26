import '../entities/vaccinator.dart';

/// Gestion de usuarios de una institucion (ADMIN_INSTITUTION).
///
/// Las escrituras son online-first: solo se confirman con respuesta exitosa del
/// servidor. La lista se cachea en la base local (Drift) para consulta sin red.
abstract interface class UsersRepository {
  /// Crea un VACCINATOR. El institutionId se resuelve en el backend desde el
  /// token del actor, no desde el cliente.
  Future<Vaccinator> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
  });

  /// Lista los usuarios de la institucion indicada (scope validado en backend).
  Future<List<Vaccinator>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  });

  /// Activa o desactiva un usuario de la institucion del actor.
  Future<Vaccinator> updateStatus(
    String accessToken, {
    required String userId,
    required String status,
  });

  /// Reemplaza los roles de un usuario de la institucion del actor.
  Future<Vaccinator> updateRoles(
    String accessToken, {
    required String userId,
    required List<String> roles,
  });
}