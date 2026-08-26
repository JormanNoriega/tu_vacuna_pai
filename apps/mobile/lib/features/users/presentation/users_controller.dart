import 'package:flutter/foundation.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/vaccinator.dart';
import '../domain/use_cases/create_vaccinator.dart';
import '../domain/use_cases/list_users.dart';

/// Controlador de la gestion de usuarios de una institucion (ADMIN_INSTITUTION).
/// Online-first: ninguna escritura se confirma hasta recibir respuesta exitosa
/// del servidor. La contrasena temporal nunca queda en el estado publico.
class UsersController extends ChangeNotifier {
  UsersController({
    required SessionManager sessionManager,
    required CreateVaccinator createVaccinator,
    required ListUsers listUsers,
  }) : this._(sessionManager, createVaccinator, listUsers);

  UsersController._(
    this._sessionManager,
    this._createVaccinator,
    this._listUsers,
  );

  final SessionManager _sessionManager;
  final CreateVaccinator _createVaccinator;
  final ListUsers _listUsers;

  List<Vaccinator> _users = const [];
  bool _isLoading = false;
  String? _error;

  List<Vaccinator> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Carga los usuarios de la institucion del admin autenticado.
  Future<void> loadUsers({required String institutionId}) async {
    final token = await _currentToken();
    if (token == null) {
      _setError('Tu sesion expiro. Inicia sesion de nuevo.');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _listUsers(token, institutionId: institutionId);
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('No se pudieron cargar los usuarios.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un vacunador. Devuelve el usuario creado o null si falla.
  Future<Vaccinator?> createVaccinator({
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) async {
    final token = await _currentToken();
    if (token == null) {
      _setError('Tu sesion expiro. Inicia sesion de nuevo.');
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _createVaccinator(
        token,
        email: email,
        fullName: fullName,
        temporaryPassword: temporaryPassword,
      );
      _users = [..._users, created];
      return created;
    } on ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (_) {
      _setError('No se pudo crear el vacunador.');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _currentToken() async {
    final session = await _sessionManager.loadSession();
    return session?.accessToken;
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}