import '../../features/auth/domain/entities/session_restore_result.dart';

/// Catalogo de operaciones de escritura que la politica offline regula.
///
/// Cada operacion declara el permiso que exige y si puede ejecutarse dentro de
/// la ventana offline autorizada. Las operaciones clinicas futuras (crear
/// paciente, atender, registrar o cancelar dosis, ...) se agregaran aqui y
/// heredaran la barrera de solo lectura sin duplicar la logica.
enum OperationPermission {
  createVaccinator(requiredPermission: 'USER_MANAGE', offlineAuthorized: false),
  updateUser(requiredPermission: 'USER_MANAGE', offlineAuthorized: false),
  createInstitution(
    requiredPermission: 'INSTITUTION_WRITE',
    offlineAuthorized: false,
  ),
  createInstitutionAdmin(
    requiredPermission: 'INSTITUTION_WRITE',
    offlineAuthorized: false,
  ),
  updateInstitutionConfig(
    requiredPermission: 'INSTITUTION_WRITE',
    offlineAuthorized: false,
  );

  const OperationPermission({
    required this.requiredPermission,
    required this.offlineAuthorized,
  });

  /// Permiso que el usuario debe tener para ejecutar la operacion.
  final String? requiredPermission;

  /// True si la operacion puede ejecutarse en modo offline autorizado.
  final bool offlineAuthorized;
}

/// Error base de la politica offline. Los controladores lo capturan para
/// mostrar un mensaje especifico en lugar de un fallo generico de red.
sealed class OfflinePolicyException implements Exception {
  const OfflinePolicyException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// La ventana offline vencio: la sesion esta en solo lectura local.
class OfflineLockedException extends OfflinePolicyException {
  const OfflineLockedException()
    : super(
        'La ventana offline vencio. Conectate e inicia sesion para seguir '
        'registrando.',
      );
}

/// La operacion requiere conexion (no esta autorizada offline).
class OfflineOperationNotAuthorizedException extends OfflinePolicyException {
  const OfflineOperationNotAuthorizedException()
    : super('Esta operacion requiere conexion. Conectate e intenta de nuevo.');
}

/// El usuario no tiene el permiso que la operacion exige.
class OfflinePermissionDeniedException extends OfflinePolicyException {
  const OfflinePermissionDeniedException()
    : super('No tienes permiso para realizar esta operacion.');
}

/// Politica central de la ventana offline (ADR-005).
///
/// Todas las operaciones de escritura la consultan antes de ejecutarse:
///
/// - [SessionStatus.signedIn] (online): la operacion corre si el usuario tiene
///   el permiso que declara.
/// - [SessionStatus.offlineAuthorized]: la operacion corre solo si esta
///   autorizada offline y el usuario tiene el permiso.
/// - [SessionStatus.offlineLocked]: solo lectura local; toda escritura lanza
///   [OfflineLockedException].
class OfflinePolicy {
  const OfflinePolicy();

  void ensureWritable({
    required SessionStatus status,
    required List<String> permissions,
    required OperationPermission operation,
  }) {
    switch (status) {
      case SessionStatus.signedIn:
        _requirePermission(permissions, operation);
      case SessionStatus.offlineAuthorized:
        if (!operation.offlineAuthorized) {
          throw const OfflineOperationNotAuthorizedException();
        }
        _requirePermission(permissions, operation);
      case SessionStatus.offlineLocked:
      case SessionStatus.signedOut:
        throw const OfflineLockedException();
    }
  }

  void _requirePermission(
    List<String> permissions,
    OperationPermission operation,
  ) {
    final required = operation.requiredPermission;
    if (required != null && !permissions.contains(required)) {
      throw const OfflinePermissionDeniedException();
    }
  }
}
