import 'package:flutter/foundation.dart';

import '../domain/entities/auth_exception.dart';
import '../domain/entities/auth_user.dart';
import '../domain/entities/session_restore_result.dart';
import '../domain/use_cases/restore_session.dart';
import '../domain/use_cases/sign_in.dart';
import '../domain/use_cases/sign_out.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required SignIn signIn,
    required RestoreSession restoreSession,
    required SignOut signOut,
  }) : this._(signIn, restoreSession, signOut);

  AuthController._(this._signIn, this._restoreSession, this._signOut);

  final SignIn _signIn;
  final RestoreSession _restoreSession;
  final SignOut _signOut;

  AuthUser? _user;
  SessionStatus _status = SessionStatus.signedOut;
  OfflineReason? _offlineReason;
  bool _isLoading = false;
  bool _isRestoring = true;
  String? _error;

  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isRestoring => _isRestoring;
  String? get error => _error;

  /// Estado de la sesion tras restaurar (online u offline).
  SessionStatus get status => _status;

  /// Razon de la ventana offline (noNetwork / backendUnavailable). Solo es
  /// relevante cuando [status] es offlineAuthorized u offlineLocked.
  OfflineReason? get offlineReason => _offlineReason;

  /// True cuando la ventana offline vencio y solo queda lectura local.
  bool get isOfflineLocked => _status == SessionStatus.offlineLocked;

  /// True cuando la sesion se abrio offline dentro de la ventana autorizada.
  bool get isOfflineAuthorized => _status == SessionStatus.offlineAuthorized;

  String get userName => _user?.name ?? '';

  /// Perfil autorizado actual. No es nulo cuando [isAuthenticated] es true.
  AuthUser? get user => _user;

  /// Restaura la sesion persistida al abrir la aplicacion. Define si se entra
  /// online, offline dentro de la ventana, o se muestra el login.
  Future<void> restoreSession() async {
    _isRestoring = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _restoreSession();
      _applyRestoreResult(result);
    } catch (_) {
      _status = SessionStatus.signedOut;
      _user = null;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _signIn(email: email, password: password);
      _status = SessionStatus.signedIn;
      _offlineReason = null;
      return true;
    } on AuthException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _signOut();
    } catch (_) {
      // La sesion local se limpia en el controller de todos modos.
    }
    _user = null;
    _status = SessionStatus.signedOut;
    _offlineReason = null;
    _error = null;
    notifyListeners();
  }

  void _applyRestoreResult(SessionRestoreResult result) {
    _status = result.status;
    _user = result.user;
    _offlineReason = result.offlineReason;
    if (result.blockedMessage != null) {
      // La sesion no pudo restaurarse (p. ej. un administrador sin validacion
      // online): se muestra el login con un aviso claro.
      _error = result.blockedMessage;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
