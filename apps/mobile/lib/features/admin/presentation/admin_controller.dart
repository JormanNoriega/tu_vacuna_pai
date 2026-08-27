import 'package:flutter/foundation.dart';

import '../../../core/auth/offline_access.dart';
import '../../../core/auth/offline_policy.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/uuid.dart';
import '../domain/entities/institution.dart';
import '../domain/entities/institution_admin.dart';
import '../domain/use_cases/create_institution.dart';
import '../domain/use_cases/create_institution_admin.dart';
import '../domain/use_cases/list_institutions.dart';
import '../domain/use_cases/update_institution_config.dart';

/// Controlador de la administracion global (SUPER_ADMIN). Online-first: ninguna
/// escritura se confirma hasta recibir respuesta exitosa del servidor.
class AdminController extends ChangeNotifier {
  AdminController({
    required SessionManager sessionManager,
    required CreateInstitution createInstitution,
    required ListInstitutions listInstitutions,
    required CreateInstitutionAdmin createInstitutionAdmin,
    required UpdateInstitutionConfig updateInstitutionConfig,
  }) : this._(
         sessionManager,
         createInstitution,
         listInstitutions,
         createInstitutionAdmin,
         updateInstitutionConfig,
       );

  AdminController._(
    this._sessionManager,
    this._createInstitution,
    this._listInstitutions,
    this._createInstitutionAdmin,
    this._updateInstitutionConfig,
  );

  final SessionManager _sessionManager;
  final CreateInstitution _createInstitution;
  final ListInstitutions _listInstitutions;
  final CreateInstitutionAdmin _createInstitutionAdmin;
  final UpdateInstitutionConfig _updateInstitutionConfig;

  List<Institution> _institutions = const [];
  bool _isLoading = false;
  String? _error;

  /// Clave de idempotencia del aprovisionamiento de admins: se genera por
  /// intencion (mismo email e institucion) y se reutiliza en reintentos; se
  /// descarta tras el exito o si cambia el destino.
  String? _pendingOperationId;
  String? _pendingEmail;
  String? _pendingInstitutionId;

  List<Institution> get institutions => List.unmodifiable(_institutions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Carga las instituciones existentes para el selector de la vista.
  Future<void> loadInstitutions() async {
    final token = await _currentToken();
    if (token == null) {
      _setError('Tu sesion expiro. Inicia sesion de nuevo.');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _institutions = await _listInstitutions(token);
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('No se pudieron cargar las instituciones.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea una institucion. Devuelve la institucion creada o null si falla.
  Future<Institution?> createInstitution({
    required OfflineAccess offline,
    required String code,
    required String name,
    int? offlineWindowHours,
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
      final created = await _createInstitution(
        token,
        offline: offline,
        code: code,
        name: name,
        offlineWindowHours: offlineWindowHours,
      );
      _institutions = [..._institutions, created];
      return created;
    } on OfflinePolicyException catch (e) {
      _setError(e.message);
      return null;
    } on ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (_) {
      _setError('No se pudo crear la institucion.');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un admin de institucion. Devuelve el usuario creado o null si falla.
  Future<InstitutionAdmin?> createInstitutionAdmin({
    required OfflineAccess offline,
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
  }) async {
    final token = await _currentToken();
    if (token == null) {
      _setError('Tu sesion expiro. Inicia sesion de nuevo.');
      return null;
    }

    if (_pendingOperationId == null ||
        _pendingEmail != email ||
        _pendingInstitutionId != institutionId) {
      _pendingOperationId = uuidV4();
      _pendingEmail = email;
      _pendingInstitutionId = institutionId;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _createInstitutionAdmin(
        token,
        offline: offline,
        email: email,
        fullName: fullName,
        institutionId: institutionId,
        temporaryPassword: temporaryPassword,
        operationId: _pendingOperationId!,
      );
      _pendingOperationId = null;
      _pendingEmail = null;
      _pendingInstitutionId = null;
      return created;
    } on OfflinePolicyException catch (e) {
      _setError(e.message);
      return null;
    } on ApiException catch (e) {
      _setError(e.message);
      return null;
    } catch (_) {
      _setError('No se pudo crear el usuario admin.');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza la ventana offline de una institucion. Devuelve true solo si la
  /// escritura se confirma con exito.
  Future<bool> updateInstitutionConfig(
    Institution institution, {
    required OfflineAccess offline,
    required int offlineWindowHours,
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
      final updated = await _updateInstitutionConfig(
        token,
        offline: offline,
        institutionId: institution.id,
        offlineWindowHours: offlineWindowHours,
      );
      _institutions = [
        for (final inst in _institutions)
          inst.id == updated.id ? updated : inst,
      ];
      return true;
    } on OfflinePolicyException catch (e) {
      _setError(e.message);
      return false;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('No se pudo actualizar la configuracion.');
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
