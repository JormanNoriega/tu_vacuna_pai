import '../entities/auth_user.dart';
import '../entities/session_restore_result.dart';

abstract interface class AuthRepository {
  /// Inicia sesion contra Supabase Auth y devuelve el perfil autorizado por
  /// Spring (`/api/v1/me`). Lanza [AuthException] si falla.
  Future<AuthUser> signIn({required String email, required String password});

  /// Restaura la sesion persistida al abrir la aplicacion. Es la entrada
  /// offline: valida online si hay red, o aplica la ventana offline con el
  /// perfil cacheado (ADR-005).
  Future<SessionRestoreResult> restoreSession();

  /// Cierra la sesion y limpia la sesion local persistida.
  Future<void> signOut();
}