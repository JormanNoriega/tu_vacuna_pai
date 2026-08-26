import 'auth_user.dart';

/// Estado de la sesion tras intentar restaurarla al abrir la aplicacion.
enum SessionStatus {
  /// Sesion validada online (red disponible y perfil revalidado).
  signedIn,

  /// No hay sesion restaurable; se muestra el login.
  signedOut,

  /// Sesion local dentro de la ventana offline: se trabaja con el perfil
  /// guardado y solo operaciones autorizadas offline.
  offlineAuthorized,

  /// Hay sesion local pero la ventana offline vencio (solo lectura).
  offlineLocked,
}

/// Resultado de la restauracion de sesion al arrancar.
class SessionRestoreResult {
  const SessionRestoreResult._(this.status, this.user);

  final SessionStatus status;

  /// Perfil autorizado. Presente cuando [status] es signedIn, offlineAuthorized
  /// u offlineLocked.
  final AuthUser? user;

  factory SessionRestoreResult.signedIn(AuthUser user) =>
      SessionRestoreResult._(SessionStatus.signedIn, user);

  factory SessionRestoreResult.signedOut() =>
      const SessionRestoreResult._(SessionStatus.signedOut, null);

  factory SessionRestoreResult.offlineAuthorized(AuthUser user) =>
      SessionRestoreResult._(SessionStatus.offlineAuthorized, user);

  factory SessionRestoreResult.offlineLocked(AuthUser user) =>
      SessionRestoreResult._(SessionStatus.offlineLocked, user);
}
