import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/me_response.dart';
import '../domain/entities/auth_exception.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/auth_repository.dart';

/// Autenticacion real: Supabase Auth (`signInWithPassword`) + perfil
/// autorizado por Spring (`GET /api/v1/me`). La sesion se persiste en
/// almacenamiento seguro.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._apiClient, this._sessionManager);

  final ApiClient _apiClient;
  final SessionManager _sessionManager;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final client = supabase.Supabase.instance.client;

    final supabase.AuthResponse response;
    try {
      response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on supabase.AuthException catch (error) {
      throw AuthException(_friendlyAuthMessage(error.message));
    }

    final session = response.session;
    if (session == null) {
      throw const AuthException('No se pudo iniciar sesion.');
    }

    final MeResponse me;
    try {
      me = await _apiClient.fetchMe(session.accessToken);
    } on ApiException catch (error) {
      await client.auth.signOut();
      throw AuthException(error.message);
    }

    final lastOnlineValidation = DateTime.parse(me.lastOnlineValidation);

    await _sessionManager.saveSession(
      SessionData(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        expiresAt:
            session.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
            : DateTime.now().add(const Duration(minutes: 15)),
        lastOnlineValidation: lastOnlineValidation,
      ),
    );

    return AuthUser(
      id: me.id,
      email: me.email,
      name: me.fullName,
      institution: InstitutionProfile(
        id: me.institution.id,
        code: me.institution.code,
        name: me.institution.name,
      ),
      roles: me.roles,
      permissions: me.permissions,
      offlineWindowHours: me.offlineWindowHours,
      lastOnlineValidation: lastOnlineValidation,
    );
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'Correo o contrasena incorrectos.';
    }
    return raw;
  }
}