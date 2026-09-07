import '../../../core/auth/offline_access.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/presentation/async_controller.dart';
import '../../../core/utils/uuid.dart';
import '../application/use_cases/update_user.dart';
import '../domain/entities/vaccinator.dart';
import '../domain/use_cases/create_vaccinator.dart';
import '../domain/use_cases/list_users.dart';

/// Controlador de la gestion de usuarios de una institucion (ADMIN_INSTITUTION).
/// Online-first: ninguna escritura se confirma hasta recibir respuesta exitosa
/// del servidor. La contrasena temporal nunca queda en el estado publico.
class UsersController extends AsyncController {
  UsersController({
    required SessionManager sessionManager,
    required CreateVaccinator createVaccinator,
    required ListUsers listUsers,
    required UpdateUser updateUser,
  }) : this._(
         createVaccinator,
         listUsers,
         updateUser,
         sessionManager: sessionManager,
       );

  UsersController._(
    this._createVaccinator,
    this._listUsers,
    this._updateUser, {
    required super.sessionManager,
  });

  final CreateVaccinator _createVaccinator;
  final ListUsers _listUsers;
  final UpdateUser _updateUser;

  List<Vaccinator> _users = const [];

  /// Clave de idempotencia del aprovisionamiento: se genera por intencion de
  /// creacion (mismo email) y se reutiliza en reintentos; se descarta tras el
  /// exito o si cambia el correo.
  String? _pendingOperationId;
  String? _pendingEmail;

  List<Vaccinator> get users => List.unmodifiable(_users);

  /// Carga los usuarios de la institucion del admin autenticado.
  Future<void> loadUsers({required String institutionId}) =>
      execute((token) async {
        _users = await _listUsers(token, institutionId: institutionId);
      });

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
    if (_pendingOperationId == null || _pendingEmail != email) {
      _pendingOperationId = uuidV4();
      _pendingEmail = email;
    }

    Vaccinator? created;
    await execute((token) async {
      created = await _createVaccinator(
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
      _users = [..._users, created!];
    });
    return created;
  }

  /// Actualiza el estado y los roles de un usuario. Online-first: devuelve
  /// true solo si ambas escrituras se confirman con exito.
  Future<bool> updateUser(
    Vaccinator user, {
    required OfflineAccess offline,
    required String status,
    required List<String> roles,
  }) async {
    var success = false;
    await execute((token) async {
      final merged = await _updateUser(
        token,
        offline: offline,
        userId: user.id,
        status: status,
        roles: roles,
      );
      _users = [for (final u in _users) u.id == merged.id ? merged : u];
      success = true;
    });
    return success;
  }
}
