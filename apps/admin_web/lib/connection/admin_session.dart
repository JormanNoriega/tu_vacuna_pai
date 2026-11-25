import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';

import 'admin_api.dart';

class SessionToken {
  const SessionToken(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;
}

abstract interface class AuthGateway {
  Future<SessionToken> signIn(String email, String password);
  Future<void> signOut();
}

/// Cliente independiente sin persistencia: no lee ni escribe la sesión antigua.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(String url, String key)
    : _client = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  final SupabaseClient _client;

  @override
  Future<SessionToken> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = response.session;
    if (session == null || session.expiresAt == null) {
      throw StateError('Sesión incompleta.');
    }
    return SessionToken(
      session.accessToken,
      DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);
}

class AdminSession extends ChangeNotifier {
  AdminSession(this.auth, this.api);
  final AuthGateway auth;
  final AdminApi api;
  bool busy = false;
  String? error;
  String? name;
  String? _token;
  String? _institutionId;
  String? institutionName;
  String? get institutionId => _institutionId;
  bool canReadUsers = false;
  bool isSuperAdmin = false;
  bool canReadHistory = false;
  bool canReadPatients = false;
  bool canReadInventory = false;
  bool globalCatalog = false;
  bool canReadCatalog = false;
  Timer? _expiry;
  bool _disposed = false;

  Future<void> signIn(String email, String password) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final session = await auth.signIn(email.trim(), password);
      if (!session.expiresAt.isAfter(DateTime.now())) {
        throw StateError('Sesión vencida');
      }
      final me = await api.fetchMe(session.token);
      final roles = me['roles'];
      final fullName = me['fullName'];
      final institution = me['institution'];
      final permissions = me['permissions'];
      if (roles is! List ||
          !roles.every((r) => r is String) ||
          !(roles.contains('SUPER_ADMIN') ||
              roles.contains('ADMIN_INSTITUTION')) ||
          fullName is! String ||
          fullName.trim().isEmpty ||
          me['id'] is! String ||
          (me['id'] as String).isEmpty ||
          institution is! Map ||
          institution['id'] is! String ||
          (institution['id'] as String).isEmpty ||
          permissions is! List ||
          !permissions.every((p) => p is String) ||
          !session.expiresAt.isAfter(DateTime.now())) {
        throw StateError('Perfil no autorizado o inválido');
      }
      name = fullName;
      isSuperAdmin = roles.contains('SUPER_ADMIN');
      canReadHistory = permissions.contains('ATTENTION_READ');
      canReadPatients = permissions.contains('PATIENT_READ');
      canReadInventory = permissions.contains('INVENTORY_READ');
      _token = session.token;
      _institutionId = institution['id'] as String;
      institutionName = institution['name'] is String
          ? institution['name'] as String
          : 'Institución';
      canReadUsers =
          permissions.contains('USER_MANAGE') ||
          permissions.contains('INSTITUTION_WRITE');
      globalCatalog =
          permissions.contains('CATALOG_GLOBAL_READ') &&
          roles.contains('SUPER_ADMIN');
      canReadCatalog =
          globalCatalog || permissions.contains('CATALOG_CONFIG_READ');
      _expiry = Timer(session.expiresAt.difference(DateTime.now()), () {
        signOut(expired: true);
      });
    } catch (_) {
      name = null;
      try {
        await auth.signOut();
      } catch (_) {
        /* No habilitar acceso. */
      }
      error = 'No fue posible validar el acceso. Verifica tus credenciales y la conexión.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> signOut({bool expired = false}) async {
    if (busy) return;
    busy = true;
    name = null;
    _token = null;
    _institutionId = null;
    institutionName = null;
    canReadUsers = false;
    isSuperAdmin = false;
    canReadHistory = false;
    canReadPatients = false;
    canReadInventory = false;
    canReadCatalog = false;
    _expiry?.cancel();
    error = expired ? 'La sesión venció. Inicia sesión nuevamente.' : null;
    notifyListeners();
    try {
      await auth.signOut();
    } catch (_) {
      error = 'La sesión se cerró en esta pantalla, pero no se pudo confirmar el cierre remoto.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> loadCatalog() {
    final token = _token;
    if (name == null || token == null || !canReadCatalog) {
      throw const AdminApiException(
        'No tienes permiso para consultar el catálogo.',
      );
    }
    return api.fetchCatalog(
      token,
      institutionId: globalCatalog ? null : _institutionId,
    );
  }

  Future<List<Map<String, dynamic>>> loadUsers() {
    final token = _token;
    final institutionId = _institutionId;
    if (name == null ||
        token == null ||
        institutionId == null ||
        !canReadUsers) {
      throw const AdminApiException(
        'No tienes permiso para consultar usuarios.',
      );
    }
    return api.fetchUsers(token, institutionId: institutionId);
  }

  Future<Map<String, dynamic>> updateUserStatus(String userId, String status) {
    final token = _token;
    if (name == null || token == null || !canReadUsers) {
      throw const AdminApiException(
        'No tienes permiso para modificar usuarios.',
      );
    }
    return api.updateUserStatus(token, userId: userId, status: status);
  }

  Future<Map<String, dynamic>> loadMetrics() {
    final token = _token;
    if (name == null || token == null) {
      throw const AdminApiException('La sesión no está disponible.');
    }
    return api.fetchMetrics(token);
  }

  Future<Map<String, dynamic>> loadHistory({
    required DateTime from,
    required DateTime to,
    required int page,
  }) {
    final token = _token;
    if (name == null || token == null || !canReadHistory) {
      throw const AdminApiException(
        'No tienes permiso para consultar el historial.',
      );
    }
    return api.fetchHistory(token, from: from, to: to, page: page);
  }

  Future<List<Map<String, dynamic>>> searchPatients({
    required String documentNumber,
    String? documentType,
  }) {
    final token = _token;
    if (name == null || token == null || !canReadPatients) {
      throw const AdminApiException(
        'No tienes permiso para buscar expedientes clínicos.',
      );
    }
    return api.searchPatients(
      token,
      documentNumber: documentNumber,
      documentType: documentType,
    );
  }

  Future<List<Map<String, dynamic>>> loadPatientAttentions(String patientId) {
    final token = _token;
    if (name == null || token == null || !canReadHistory) {
      throw const AdminApiException(
        'No tienes permiso para consultar las atenciones del paciente.',
      );
    }
    return api.fetchPatientAttentions(token, patientId: patientId);
  }

  Future<Map<String, dynamic>> loadReportSummary({
    required DateTime from,
    required DateTime to,
  }) {
    final token = _token;
    if (name == null || token == null || !canReadHistory) {
      throw const AdminApiException(
        'No tienes permiso para consultar el reporte.',
      );
    }
    return api.fetchReportSummary(token, from: from, to: to);
  }

  Future<AdminReport> downloadReport({
    required DateTime from,
    required DateTime to,
    required String format,
  }) {
    final token = _token;
    if (name == null || token == null || !canReadHistory) {
      throw const AdminApiException('No tienes permiso para exportar datos.');
    }
    return api.downloadReport(token, from: from, to: to, format: format);
  }

  Future<List<Map<String, dynamic>>> loadInventoryList(String resource) {
    final token = _token;
    final institution = _institutionId;
    if (name == null ||
        token == null ||
        institution == null ||
        !canReadInventory) {
      throw const AdminApiException(
        'No tienes permiso para consultar inventario.',
      );
    }
    return api.fetchInventoryList(
      token,
      institutionId: institution,
      resource: resource,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    api.close();
    super.dispose();
  }
}
