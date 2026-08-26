import 'package:flutter/foundation.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/vaccinator.dart';
import '../domain/use_cases/create_vaccinator.dart';
import '../domain/use_cases/list_users.dart';
import '../domain/use_cases/update_user_roles.dart';
import '../domain/use_cases/update_user_status.dart';

/// Controlador de la gestion de usuarios de una institucion (ADMIN_INSTITUTION).
/// Online-first: ninguna escritura se confirma hasta recibir respuesta exitosa
/// del servidor. La contrasena temporal nunca queda en el estado publico.
class UsersController extends ChangeNotifier {
  UsersController({
    required SessionManager sessionManager,
    required CreateVaccinator createVaccinator,
    required ListUsers listUsers,
    required UpdateUserStatus updateUserStatus,
    required UpdateUserRoles updateUserRoles,
  }) : this._(sessionManager, createVaccinator, listUsers, updateUserStatus, updateUserRoles);

  UsersController._(
    this._sessionManager,
    this._createVaccinator,
    this._listUsers,
    this._updateUserStatus,
    this._updateUserRoles,
  );

  final SessionManager _sessionManager;
  final CreateVaccinator _createVaccinator;
  final ListUsers _listUsers;
  final UpdateUserStatus _updateUserStatus;
  final UpdateUserRoles _updateUserRoles;

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

  /// Actualiza el estado y los roles de un usuario. Online-first: devuelve
  /// true solo si ambas escrituras se confirman con exito.
  Future<bool> updateUser(
    Vaccinator user, {
    required String status,
    required List<String> roles,
  }) async {
    final token = await _currentToken();
    if (token == null) {
      _setError('Tu sesion expiro. Inicia sesion de nuevo.');
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedStatus = await _updateUserStatus(
        token,
        userId: user.id,
        status: status,
      );
      final updatedRoles = await _updateUserRoles(
        token,
        userId: user.id,
        roles: roles,
      );
      final merged = Vaccinator(
        id: updatedStatus.id,
        email: updatedStatus.email,
        fullName: updatedStatus.fullName,
        institutionId: updatedStatus.institutionId,
        roles: updatedRoles.roles,
        status: updatedStatus.status,
      );
      _users = [
        for (final u in _users) u.id == merged.id ? merged : u,
      ];
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('No se pudo actualizar el usuario.');
      return false;
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