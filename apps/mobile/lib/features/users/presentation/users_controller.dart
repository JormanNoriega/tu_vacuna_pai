import 'package:flutter/foundation.dart';

import '../../../core/auth/offline_access.dart';
import '../../../core/auth/offline_policy.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/uuid.dart';
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
  }) : this._(
         sessionManager,
         createVaccinator,
         listUsers,
         updateUserStatus,
         updateUserRoles,
       );

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

  /// Clave de idempotencia del aprovisionamiento: se genera por intencion de
  /// creacion (mismo email) y se reutiliza en reintentos; se descarta tras el
  /// exito o si cambia el correo.
  String? _pendingOperationId;
  String? _pendingEmail;

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
    required OfflineAccess offline,
    required String email,
    required String fullName,
    required String temporaryPassword,
    required String documentType,
    required String documentNumber,
    String? phone,
    String? birthDate,
    String? gender,
    required String professionCode,
    String? professionalRegistrationNumber,
    String? professionalRegistrationType,
  }) async {
    final token = await _currentToken();
    if (token == null) {
      _setError('Tu sesion expiro. Inicia sesion de nuevo.');
      return null;
    }

    if (_pendingOperationId == null || _pendingEmail != email) {
      _pendingOperationId = uuidV4();
      _pendingEmail = email;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _createVaccinator(
        token,
        offline: offline,
        email: email,
        fullName: fullName,
        temporaryPassword: temporaryPassword,
        operationId: _pendingOperationId!,
        documentType: documentType,
        documentNumber: documentNumber,
        phone: phone,
        birthDate: birthDate,
        gender: gender,
        professionCode: professionCode,
        professionalRegistrationNumber: professionalRegistrationNumber,
        professionalRegistrationType: professionalRegistrationType,
      );
      _pendingOperationId = null;
      _pendingEmail = null;
      _users = [..._users, created];
      return created;
    } on OfflinePolicyException catch (e) {
      _setError(e.message);
      return null;
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
    required OfflineAccess offline,
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
        offline: offline,
        userId: user.id,
        status: status,
      );
      final updatedRoles = await _updateUserRoles(
        token,
        offline: offline,
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
        documentType: updatedStatus.documentType,
        documentNumber: updatedStatus.documentNumber,
        phone: updatedStatus.phone,
        birthDate: updatedStatus.birthDate,
        gender: updatedStatus.gender,
        professionCode: updatedStatus.professionCode,
        professionalRegistrationNumber:
            updatedStatus.professionalRegistrationNumber,
        professionalRegistrationType:
            updatedStatus.professionalRegistrationType,
      );
      _users = [for (final u in _users) u.id == merged.id ? merged : u];
      return true;
    } on OfflinePolicyException catch (e) {
      _setError(e.message);
      return false;
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
