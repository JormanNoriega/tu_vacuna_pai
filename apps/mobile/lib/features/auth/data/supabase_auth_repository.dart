import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/auth/offline_authorization_service.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_info.dart';
import '../../../core/network/me_response.dart';
import '../domain/entities/auth_exception.dart';
import '../domain/entities/auth_user.dart';
import '../domain/entities/session_restore_result.dart';
import '../domain/repositories/auth_repository.dart';
import 'local_session_store.dart';

/// Resultado de la validacion online durante la restauracion de sesion.
enum _OnlineOutcome {
  /// El token y el perfil se revalidaron correctamente.
  authenticated,

  /// El token es invalido y no pudo renovarse: se debe cerrar la sesion.
  invalidCredentials,

  /// Hay conectividad pero el backend no respondio correctamente (5xx o
  /// inalcanzable): no hay una decision de credenciales.
  unreachable,
}

/// Autenticacion real: Supabase Auth (`signInWithPassword`) + perfil
/// autorizado por Spring (`GET /api/v1/me`). La sesion se persiste en
/// almacenamiento seguro (tokens) y el perfil autorizado en la base local.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._apiClient,
    this._sessionManager,
    this._localSessionStore,
    this._networkInfo, {
    this._offlineAuthorization = const OfflineAuthorizationService(),
    Future<supabase.Session?> Function(SessionData stored)? refreshSession,
  }) : _refreshSession = refreshSession ?? _supabaseRefreshSession;

  final ApiClient _apiClient;
  final SessionManager _sessionManager;
  final LocalSessionStore _localSessionStore;
  final NetworkInfo _networkInfo;
  final OfflineAuthorizationService _offlineAuthorization;

  /// Renueva el access token. Inyectable para pruebas; en produccion usa el
  /// cliente de Supabase.
  final Future<supabase.Session?> Function(SessionData stored) _refreshSession;

  static Future<supabase.Session?> _supabaseRefreshSession(
    SessionData stored,
  ) async {
    if (stored.refreshToken.isEmpty) return null;
    try {
      final response = await supabase.Supabase.instance.client.auth
          .refreshSession(stored.refreshToken);
      return response.session;
    } on supabase.AuthException {
      return null;
    }
  }

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
    } catch (_) {
      // Cualquier otro fallo (p. ej. parseo) se muestra como error de red para
      // que la app avise y nunca se quede colgada ni lance excepcion sin atrapar.
      await client.auth.signOut();
      throw const AuthException(
        'No se pudo conectar con el servidor. Intenta de nuevo.',
      );
    }

    return _persistOnlineSession(
      SessionData(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        expiresAt: session.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
            : DateTime.now().add(const Duration(minutes: 15)),
        lastOnlineValidation: DateTime.now(),
      ),
      me,
    );
  }

  @override
  Future<SessionRestoreResult> restoreSession() async {
    final stored = await _sessionManager.loadSession();
    final profile = await _localSessionStore.loadProfile();
    if (stored == null) {
      return SessionRestoreResult.signedOut();
    }

    final isAdmin =
        profile != null &&
        (profile.roles.contains('ADMIN_INSTITUTION') ||
            profile.roles.contains('SUPER_ADMIN'));

    // Con red se revalida online antes de decidir. La expiracion del access
    // token no bloquea el offline: la ventana es politica propia.
    if (await _networkInfo.isConnected) {
      final outcome = await _validateOnline(stored);
      if (outcome == _OnlineOutcome.authenticated) {
        final refreshed = await _localSessionStore.loadProfile();
        return SessionRestoreResult.signedIn(refreshed ?? profile!);
      }
      if (outcome == _OnlineOutcome.invalidCredentials) {
        // Token revocado, usuario desactivado o sin permisos vigentes.
        await _invalidateSession();
        return SessionRestoreResult.signedOut();
      }
      // Backend inalcanzable o 5xx CON conectividad del dispositivo: los
      // administradores permanecen online (online-first) y las vistas muestran
      // el error; el resto entra a la ventana offline con razon
      // BACKEND_UNAVAILABLE, sin perder la capacidad de trabajar localmente.
      if (isAdmin) {
        return SessionRestoreResult.signedIn(profile);
      }
      return _offlineRestore(profile, OfflineReason.backendUnavailable);
    }

    // Sin conectividad real del dispositivo: los administradores permanecen
    // online-first; el resto cae a la ventana offline por razon NO_NETWORK.
    if (isAdmin) {
      return SessionRestoreResult.signedIn(profile);
    }
    return _offlineRestore(profile, OfflineReason.noNetwork);
  }

  /// Decide entre ventana offline autorizada o vencida para el perfil local.
  /// [reason] solo afecta la etiqueta visual; la autorizacion la define
  /// [OfflineAuthorizationService].
  SessionRestoreResult _offlineRestore(
    AuthUser? profile,
    OfflineReason reason,
  ) {
    if (profile == null) {
      return SessionRestoreResult.signedOut();
    }
    final state = _offlineAuthorization.evaluate(
      lastOnlineValidation: profile.lastOnlineValidation,
      offlineWindowHours: profile.offlineWindowHours,
    );
    if (state == OfflineAuthorizationState.authorized) {
      return SessionRestoreResult.offlineAuthorized(profile, reason: reason);
    }
    return SessionRestoreResult.offlineLocked(profile, reason: reason);
  }

  /// Intenta validar online. Primero usa el access token vigente; solo si el
  /// servidor lo rechaza (401/403) renueva y reintenta. Evita caer a la
  /// ventana offline por un fallo transitorio del refresh teniendo internet.
  Future<_OnlineOutcome> _validateOnline(SessionData stored) async {
    final tokenStillValid = stored.expiresAt.isAfter(DateTime.now());

    if (tokenStillValid) {
      try {
        final me = await _apiClient.fetchMe(stored.accessToken);
        await _persistOnlineSession(stored, me);
        return _OnlineOutcome.authenticated;
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          return _refreshAndValidate(stored);
        }
        return _OnlineOutcome.unreachable;
      }
    }
    return _refreshAndValidate(stored);
  }

  Future<_OnlineOutcome> _refreshAndValidate(SessionData stored) async {
    final refreshed = await _refreshSession(stored);
    if (refreshed == null) {
      return _OnlineOutcome.invalidCredentials;
    }
    try {
      final me = await _apiClient.fetchMe(refreshed.accessToken);
      await _persistOnlineSession(
        SessionData(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken ?? stored.refreshToken,
          expiresAt: refreshed.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(refreshed.expiresAt! * 1000)
              : stored.expiresAt,
          lastOnlineValidation: stored.lastOnlineValidation,
        ),
        me,
      );
      return _OnlineOutcome.authenticated;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return _OnlineOutcome.invalidCredentials;
      }
      return _OnlineOutcome.unreachable;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabase.Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Se limpia la sesion local aun si el signOut remoto falla.
    }
    await _invalidateSession();
  }

  Future<AuthUser> _persistOnlineSession(
    SessionData sessionData,
    MeResponse me,
  ) async {
    final lastOnlineValidation = DateTime.parse(me.lastOnlineValidation);

    await _sessionManager.saveSession(
      SessionData(
        accessToken: sessionData.accessToken,
        refreshToken: sessionData.refreshToken,
        expiresAt: sessionData.expiresAt,
        lastOnlineValidation: lastOnlineValidation,
      ),
    );

    final user = AuthUser(
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

    await _localSessionStore.saveProfile(user);
    return user;
  }

  Future<void> _invalidateSession() async {
    await _sessionManager.clear();
    await _localSessionStore.clearProfile();
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
