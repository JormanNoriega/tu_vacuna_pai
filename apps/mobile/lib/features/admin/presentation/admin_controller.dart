import '../../../core/auth/offline_access.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/presentation/async_controller.dart';
import '../../../core/utils/uuid.dart';
import '../application/use_cases/list_institution_admins.dart';
import '../domain/entities/clone_catalog_result.dart';
import '../domain/entities/institution.dart';
import '../domain/entities/institution_admin.dart';
import '../domain/use_cases/clone_catalog_to_institution.dart';
import '../domain/use_cases/create_institution.dart';
import '../domain/use_cases/create_institution_admin.dart';
import '../domain/use_cases/list_institutions.dart';
import '../domain/use_cases/update_institution_config.dart';

/// Controlador de la administracion global (SUPER_ADMIN). Online-first: ninguna
/// escritura se confirma hasta recibir respuesta exitosa del servidor.
class AdminController extends AsyncController {
  AdminController({
    required SessionManager sessionManager,
    required CreateInstitution createInstitution,
    required ListInstitutions listInstitutions,
    required CreateInstitutionAdmin createInstitutionAdmin,
    required UpdateInstitutionConfig updateInstitutionConfig,
    ListInstitutionAdmins? listInstitutionAdmins,
    CloneCatalogToInstitution? cloneCatalogToInstitution,
  }) : this._(
         createInstitution,
         listInstitutions,
         createInstitutionAdmin,
         updateInstitutionConfig,
         listInstitutionAdmins,
         cloneCatalogToInstitution,
         sessionManager: sessionManager,
       );

  AdminController._(
    this._createInstitution,
    this._listInstitutions,
    this._createInstitutionAdmin,
    this._updateInstitutionConfig,
    this._listInstitutionAdmins,
    this._cloneCatalogToInstitution, {
    required super.sessionManager,
  });

  final CreateInstitution _createInstitution;
  final ListInstitutions _listInstitutions;
  final CreateInstitutionAdmin _createInstitutionAdmin;
  final UpdateInstitutionConfig _updateInstitutionConfig;
  final ListInstitutionAdmins? _listInstitutionAdmins;
  final CloneCatalogToInstitution? _cloneCatalogToInstitution;

  List<Institution> _institutions = const [];
  List<InstitutionAdmin> _admins = const [];
  bool _adminsLoading = false;

  /// Clave de idempotencia del aprovisionamiento de admins: se genera por
  /// intencion (mismo email e institucion) y se reutiliza en reintentos; se
  /// descarta tras el exito o si cambia el destino.
  String? _pendingOperationId;
  String? _pendingEmail;
  String? _pendingInstitutionId;

  List<Institution> get institutions => List.unmodifiable(_institutions);
  List<InstitutionAdmin> get admins => List.unmodifiable(_admins);
  bool get adminsLoading => _adminsLoading;

  /// Carga las instituciones existentes para el selector de la vista.
  Future<void> loadInstitutions() => execute((token) async {
    _institutions = await _listInstitutions(token);
  });

  /// Carga los administradores de institucion agregando los resultados de cada
  /// institucion. Solo disponible cuando se inyecto [ListInstitutionAdmins].
  Future<void> loadAdmins() async {
    final list = _listInstitutionAdmins;
    if (list == null) return;
    _adminsLoading = true;
    notifyListeners();
    try {
      await execute((token) async {
        _admins = await list(token);
      });
    } finally {
      _adminsLoading = false;
      notifyListeners();
    }
  }

  /// Nombre de la institucion para un [InstitutionAdmin].
  String? institutionNameOf(String institutionId) {
    for (final institution in _institutions) {
      if (institution.id == institutionId) return institution.name;
    }
    return null;
  }

  /// Cantidad de administradores registrados para una institucion.
  int adminsFor(String institutionId) =>
      _admins.where((admin) => admin.institutionId == institutionId).length;

  /// Crea una institucion. Devuelve la institucion creada o null si falla.
  Future<Institution?> createInstitution({
    required OfflineAccess offline,
    required String code,
    required String name,
    int? offlineWindowHours,
  }) async {
    Institution? created;
    await execute((token) async {
      created = await _createInstitution(
        token,
        offline: offline,
        code: code,
        name: name,
        offlineWindowHours: offlineWindowHours,
      );
      _institutions = [..._institutions, created!];
    });
    return created;
  }

  /// Crea un admin de institucion. Devuelve el usuario creado o null si falla.
  Future<InstitutionAdmin?> createInstitutionAdmin({
    required OfflineAccess offline,
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
  }) async {
    if (_pendingOperationId == null ||
        _pendingEmail != email ||
        _pendingInstitutionId != institutionId) {
      _pendingOperationId = uuidV4();
      _pendingEmail = email;
      _pendingInstitutionId = institutionId;
    }

    InstitutionAdmin? created;
    await execute((token) async {
      created = await _createInstitutionAdmin(
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
    });
    return created;
  }

  /// Actualiza la ventana offline de una institucion. Devuelve true solo si la
  /// escritura se confirma con exito.
  Future<bool> updateInstitutionConfig(
    Institution institution, {
    required OfflineAccess offline,
    required int offlineWindowHours,
  }) async {
    var success = false;
    await execute((token) async {
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
      success = true;
    });
    return success;
  }

  /// Clona el catalogo global hacia una institucion. Devuelve el resumen del
  /// clonado o null si falla.
  Future<CloneCatalogResult?> cloneCatalogToInstitution(
    Institution institution, {
    required OfflineAccess offline,
    required bool includeDefaultConfig,
  }) async {
    final clone = _cloneCatalogToInstitution;
    if (clone == null) {
      _setError('El clonado de catalogo no esta disponible.');
      return null;
    }
    CloneCatalogResult? result;
    await execute((token) async {
      result = await clone(
        token,
        offline: offline,
        institutionId: institution.id,
        includeDefaultConfig: includeDefaultConfig,
      );
    });
    return result;
  }

  void _setError(String message) => setError(message);
}
