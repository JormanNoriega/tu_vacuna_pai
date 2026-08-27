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
  const SessionRestoreResult._(
    this.status,
    this.user,
    this.offlineReason,
    this.blockedMessage,
  );

  final SessionStatus status;

  /// Perfil autorizado. Presente cuando [status] es signedIn, offlineAuthorized
  /// u offlineLocked.
  final AuthUser? user;

  /// Razon de la ventana offline. Solo es relevante cuando [status] es
  /// offlineAuthorized u offlineLocked.
  final OfflineReason? offlineReason;

  /// Aviso claro para la pantalla de login cuando una sesion no pudo
  /// restaurarse porque el rol requiere conexion (p. ej. un administrador sin
  /// validacion online exitosa). Solo es relevante cuando [status] es
  /// signedOut.
  final String? blockedMessage;

  factory SessionRestoreResult.signedIn(AuthUser user) =>
      SessionRestoreResult._(SessionStatus.signedIn, user, null, null);

  factory SessionRestoreResult.signedOut() =>
      const SessionRestoreResult._(SessionStatus.signedOut, null, null, null);

  /// Un rol online-first (ADMIN_INSTITUTION, SUPER_ADMIN) no pudo validarse en
  /// linea: no entra a la ventana offline, se devuelve al login con un aviso.
  /// La sesion almacenada se conserva para restaurar online en el proximo
  /// arranque con conectividad.
  factory SessionRestoreResult.adminBlocked(OfflineReason reason) =>
      SessionRestoreResult._(
        SessionStatus.signedOut,
        null,
        reason,
        reason == OfflineReason.noNetwork
            ? 'Para iniciar sesion como administrador necesitas conexion a '
                  'Internet. Verifica tu red e intentalo de nuevo.'
            : 'El servidor no esta disponible. Los administradores deben '
                  'iniciar sesion en linea; intentalo de nuevo en un momento.',
      );

  factory SessionRestoreResult.offlineAuthorized(
    AuthUser user, {
    OfflineReason reason = OfflineReason.noNetwork,
  }) => SessionRestoreResult._(
    SessionStatus.offlineAuthorized,
    user,
    reason,
    null,
  );

  factory SessionRestoreResult.offlineLocked(
    AuthUser user, {
    OfflineReason reason = OfflineReason.noNetwork,
  }) => SessionRestoreResult._(SessionStatus.offlineLocked, user, reason, null);
}
