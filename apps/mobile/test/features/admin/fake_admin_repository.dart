import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/clone_catalog_result.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/institution_admin.dart';
import 'package:tu_vacuna_pai/features/admin/domain/repositories/admin_repository.dart';

/// Repositorio en memoria para pruebas del [AdminController].
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({this.failOnCreate = false});

  bool failOnCreate;
  bool failOnUpdate = false;
  final List<Institution> institutions = [];
  final List<InstitutionAdmin> admins = [];
  String? lastPassword;
  String? lastOperationId;

  @override
  Future<Institution> createInstitution(
    String accessToken, {
    required String code,
    required String name,
    int? offlineWindowHours,
  }) async {
    if (failOnCreate) {
      throw StateError('Fallo simulado');
    }
    final institution = Institution(
      id: 'inst-${institutions.length + 1}',
      code: code,
      name: name,
      status: 'ACTIVE',
      offlineWindowHours: offlineWindowHours ?? 72,
    );
    institutions.add(institution);
    return institution;
  }

  @override
  Future<List<Institution>> listInstitutions(String accessToken) async {
    return List.unmodifiable(institutions);
  }

  @override
  Future<InstitutionAdmin> createInstitutionAdmin(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
    required String operationId,
  }) async {
    lastOperationId = operationId;
    if (failOnCreate) {
      throw StateError('Fallo simulado');
    }
    lastPassword = temporaryPassword;
    final admin = InstitutionAdmin(
      id: 'user-${admins.length + 1}',
      email: email,
      fullName: fullName,
      institutionId: institutionId,
      roles: const ['ADMIN_INSTITUTION'],
    );
    admins.add(admin);
    return admin;
  }

  @override
  Future<List<InstitutionAdmin>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) async {
    return admins
        .where((admin) => admin.institutionId == institutionId)
        .toList();
  }

  @override
  Future<Institution> updateInstitutionConfig(
    String accessToken, {
    required String institutionId,
    required int offlineWindowHours,
  }) async {
    if (failOnUpdate) {
      throw StateError('Fallo simulado');
    }
    final index = institutions.indexWhere((inst) => inst.id == institutionId);
    final current = institutions[index];
    final updated = Institution(
      id: current.id,
      code: current.code,
      name: current.name,
      status: current.status,
      offlineWindowHours: offlineWindowHours,
    );
    institutions[index] = updated;
    return updated;
  }

  @override
  Future<CloneCatalogResult> cloneCatalogToInstitution(
    String accessToken, {
    required String institutionId,
    required bool includeDefaultConfig,
  }) async {
    if (failOnCreate) {
      throw StateError('Fallo simulado');
    }
    return CloneCatalogResult(
      vaccinesEnabled: 3,
      optionsCopied: includeDefaultConfig ? 12 : 0,
      vaccinesTotal: 3,
    );
  }
}

/// SessionManager con un token fijo para pruebas.
class FakeSessionManager extends SessionManager {
  FakeSessionManager(this._token) : super(const FlutterSecureStorage());

  final String? _token;

  @override
  Future<SessionData?> loadSession() async {
    final token = _token;
    if (token == null) return null;
    return SessionData(
      accessToken: token,
      refreshToken: '',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      lastOnlineValidation: DateTime.now(),
    );
  }
}
