import 'package:flutter/foundation.dart';

import '../auth/session_manager.dart';
import '../network/api_exception.dart';
import '../auth/offline_policy.dart';

/// Sesion ausente o expirada al ejecutar una operacion autenticada.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

/// Infraestructura de presentacion repetitiva: token + loading + mapeo de
/// errores.
///
/// Solo resuelve la ceremonia transversal de los controladores (obtener token,
/// marcar loading, traducir errores y notificar). NO contiene OfflinePolicy,
/// SyncEngine, outbox, permisos ni reglas de negocio: eso vive en las capas de
/// aplicacion/dominio o en los repositorios.
abstract class AsyncController extends ChangeNotifier {
  AsyncController({required this.sessionManager});

  final SessionManager sessionManager;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Ejecuta una accion autenticada envolviendo loading y mapeo de errores.
  ///
  /// Si no hay sesion, se asigna el mensaje de sesion expirada sin ejecutar la
  /// accion. Los errores [OfflinePolicyException] y [ApiException] se traducen
  /// con [mapOfflineError] y [mapApiError] respectivamente.
  Future<void> execute(Future<void> Function(String token) action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await sessionManager.loadSession();
      final token = session?.accessToken;
      if (token == null) {
        throw const SessionExpiredException();
      }
      await action(token);
    } on SessionExpiredException {
      _error = 'Tu sesion expiro. Inicia sesion de nuevo.';
    } on OfflinePolicyException catch (e) {
      _error = mapOfflineError(e);
    } on ApiException catch (e) {
      _error = mapApiError(e);
    } catch (_) {
      _error = 'Ocurrio un error inesperado';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hook opcional para traducir errores de politica offline por feature.
  String mapOfflineError(OfflinePolicyException e) => e.message;

  /// Hook opcional para traducir [ApiException] por feature (p. ej. 409).
  String mapApiError(ApiException e) => e.message;

  /// Fija un error y notifica. Pensado para validaciones previas a [execute]
  /// (p. ej. politica offline) que no pasan por el flujo token/loading.
  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
