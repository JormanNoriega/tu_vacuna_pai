import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  /// Inicia sesion contra Supabase Auth y devuelve el perfil autorizado por
  /// Spring (`/api/v1/me`). Lanza [AuthException] si falla.
  Future<AuthUser> signIn({required String email, required String password});
}
