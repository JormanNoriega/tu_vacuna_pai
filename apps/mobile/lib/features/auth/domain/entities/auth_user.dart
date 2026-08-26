/// Perfil remoto del usuario autenticado (`RemoteUserProfile`).
///
/// Representa lo ultimo que Spring autorizo en `GET /api/v1/me`. No es una
/// fuente de verdad permanente: puede quedar obsoleto hasta la siguiente
/// validacion online.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.institution,
    required this.roles,
    required this.permissions,
    required this.offlineWindowHours,
    required this.lastOnlineValidation,
  });

  final String id;
  final String email;
  final String name;
  final InstitutionProfile institution;
  final List<String> roles;
  final List<String> permissions;
  final int offlineWindowHours;
  final DateTime lastOnlineValidation;

  /// True si el usuario tiene el permiso dado. Base para decidir que mostrar en
  /// la UI. La autoridad definitiva sigue siendo el backend.
  bool hasPermission(String permission) => permissions.contains(permission);

  /// True si el usuario tiene todos los permisos indicados.
  bool hasAllPermissions(Iterable<String> required) =>
      required.every(hasPermission);

  /// True si el usuario tiene el rol dado.
  bool hasRole(String role) => roles.contains(role);
}

class InstitutionProfile {
  const InstitutionProfile({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;
}