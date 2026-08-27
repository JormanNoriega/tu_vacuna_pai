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

/// Por que se entro a la ventana offline. Distingue la conectividad del
/// dispositivo (no hay red) de la disponibilidad del backend (hay red pero el
/// servidor no responde). Solo afecta la etiqueta visual del banner; la
/// autorizacion de escritura sigue viviendo en [SessionStatus].
enum OfflineReason {
  /// El dispositivo no tiene ninguna conexion de red.
  noNetwork,

  /// Hay conectividad pero el backend no esta disponible (unreachable/5xx).
  backendUnavailable,
}

/// Resultado de la restauracion de sesion al arrancar.
class SessionRestoreResult {
  const SessionRestoreResult._(this.status, this.user, this.offlineReason);

  final SessionStatus status;

  /// Perfil autorizado. Presente cuando [status] es signedIn, offlineAuthorized
  /// u offlineLocked.
  final AuthUser? user;

  /// Razon de la ventana offline. Solo es relevante cuando [status] es
  /// offlineAuthorized u offlineLocked.
  final OfflineReason? offlineReason;

  factory SessionRestoreResult.signedIn(AuthUser user) =>
      SessionRestoreResult._(SessionStatus.signedIn, user, null);

  factory SessionRestoreResult.signedOut() =>
      const SessionRestoreResult._(SessionStatus.signedOut, null, null);

  factory SessionRestoreResult.offlineAuthorized(
    AuthUser user, {
    OfflineReason reason = OfflineReason.noNetwork,
  }) => SessionRestoreResult._(SessionStatus.offlineAuthorized, user, reason);

  factory SessionRestoreResult.offlineLocked(
    AuthUser user, {
    OfflineReason reason = OfflineReason.noNetwork,
  }) => SessionRestoreResult._(SessionStatus.offlineLocked, user, reason);
}