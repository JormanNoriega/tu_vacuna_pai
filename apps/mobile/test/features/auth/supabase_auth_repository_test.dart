import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/core/network/network_info.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';
import 'package:tu_vacuna_pai/features/auth/data/local_session_store.dart';
import 'package:tu_vacuna_pai/features/auth/data/supabase_auth_repository.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';

class _FakeSessionManager extends SessionManager {
  _FakeSessionManager(this.data) : super(const FlutterSecureStorage());

  SessionData? data;

  @override
  Future<SessionData?> loadSession() async => data;

  @override
  Future<void> saveSession(SessionData session) async {
    data = session;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

class _FakeNetworkInfo implements NetworkInfo {
  _FakeNetworkInfo(this.connected);

  bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get connectivityChanges => const Stream.empty();
}

void main() {
  late AppDatabase database;
  late LocalSessionStore store;
  late _FakeSessionManager sessionManager;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = LocalSessionStore(database);
    sessionManager = _FakeSessionManager(null);
  });

  tearDown(() async {
    await database.close();
  });

  SessionData storedSession({
    DateTime? expiresAt,
    String refreshToken = 'refresh-token',
  }) => SessionData(
    accessToken: 'access-token',
    refreshToken: refreshToken,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
    lastOnlineValidation: DateTime.now(),
  );

  Map<String, dynamic> meJson({List<String> roles = const ['VACCINATOR']}) => {
    'id': 'user-1',
    'email': 'usuario@pai.test',
    'fullName': 'Usuario Demo',
    'institution': {'id': 'inst-1', 'code': 'HOSP-A', 'name': 'Hospital A'},
    'roles': roles,
    'permissions': const ['ATTENTION_CREATE'],
    'offlineWindowHours': 72,
    'lastOnlineValidation': DateTime.now().toUtc().toIso8601String(),
  };

  AuthUser profile({
    List<String> roles = const ['VACCINATOR'],
    List<String> permissions = const ['ATTENTION_CREATE'],
    DateTime? lastOnlineValidation,
  }) => AuthUser(
    id: 'user-1',
    email: 'usuario@pai.test',
    name: 'Usuario Demo',
    institution: const InstitutionProfile(
      id: 'inst-1',
      code: 'HOSP-A',
      name: 'Hospital A',
    ),
    roles: roles,
    permissions: permissions,
    offlineWindowHours: 72,
    lastOnlineValidation: lastOnlineValidation ?? DateTime.now(),
  );

  SupabaseAuthRepository build({
    required http.Client httpClient,
    _FakeNetworkInfo? network,
    bool Function()? refreshFails,
  }) {
    return SupabaseAuthRepository(
      ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: httpClient,
      ),
      sessionManager,
      store,
      network ?? _FakeNetworkInfo(true),
      refreshSession: (stored) async {
        if (refreshFails?.call() ?? true) return null;
        return null;
      },
    );
  }

  test(
    'restaura online cuando el token es vigente y el backend responde',
    () async {
      sessionManager.data = storedSession();
      final repository = build(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/me');
          return http.Response(
            jsonEncode(meJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await repository.restoreSession();

      expect(result.status, SessionStatus.signedIn);
      expect(result.user, isNotNull);
      expect(await store.loadProfile(), isNotNull);
    },
  );

  test(
    'no cae a offline cuando el refresh esta vacio pero el token es vigente',
    () async {
      sessionManager.data = storedSession(refreshToken: '');
      final repository = build(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode(meJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await repository.restoreSession();

      expect(result.status, SessionStatus.signedIn);
    },
  );

  test('no deja entrar a un admin cuando el backend falla con 5xx', () async {
    sessionManager.data = storedSession();
    await store.saveProfile(
      profile(
        roles: const ['ADMIN_INSTITUTION'],
        permissions: const ['USER_MANAGE'],
      ),
    );
    final repository = build(
      httpClient: MockClient((request) async {
        return http.Response('server error', 500);
      }),
    );

    final result = await repository.restoreSession();

    expect(result.status, SessionStatus.signedOut);
    expect(result.blockedMessage, isNotNull);
    // La sesion almacenada se conserva para restaurar online mas adelante.
    expect(sessionManager.data, isNotNull);
  });

  test(
    'un vaccinator cae a la ventana offline cuando el backend falla con 5xx',
    () async {
      sessionManager.data = storedSession();
      await store.saveProfile(profile());
      final repository = build(
        httpClient: MockClient((request) async {
          return http.Response('server error', 500);
        }),
      );

      final result = await repository.restoreSession();

      expect(result.status, SessionStatus.offlineAuthorized);
      // Hay conectividad pero el backend no responde: razon backendUnavailable.
      expect(result.offlineReason, OfflineReason.backendUnavailable);
    },
  );

  test('ventana vencida con backend caido queda en solo lectura', () async {
    sessionManager.data = storedSession();
    await store.saveProfile(
      profile(
        lastOnlineValidation: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );
    final repository = build(
      httpClient: MockClient((request) async {
        return http.Response('server error', 500);
      }),
    );

    final result = await repository.restoreSession();

    expect(result.status, SessionStatus.offlineLocked);
    expect(result.offlineReason, OfflineReason.backendUnavailable);
  });

  test('sin conectividad un vaccinator usa la ventana offline', () async {
    sessionManager.data = storedSession();
    await store.saveProfile(profile());
    final repository = build(
      httpClient: MockClient((request) async {
        fail('no deberia llamarse a la API sin conectividad');
      }),
      network: _FakeNetworkInfo(false),
    );

    final result = await repository.restoreSession();

    expect(result.status, SessionStatus.offlineAuthorized);
    expect(result.offlineReason, OfflineReason.noNetwork);
  });

  test('no deja entrar a un admin sin conectividad', () async {
    sessionManager.data = storedSession();
    await store.saveProfile(
      profile(
        roles: const ['ADMIN_INSTITUTION'],
        permissions: const ['USER_MANAGE'],
      ),
    );
    final repository = build(
      httpClient: MockClient((request) async {
        fail('no deberia llamarse a la API sin conectividad');
      }),
      network: _FakeNetworkInfo(false),
    );

    final result = await repository.restoreSession();

    expect(result.status, SessionStatus.signedOut);
    expect(result.blockedMessage, isNotNull);
  });

  test('un admin entra online cuando el backend responde', () async {
    sessionManager.data = storedSession();
    await store.saveProfile(
      profile(
        roles: const ['SUPER_ADMIN'],
        permissions: const ['INSTITUTION_WRITE'],
      ),
    );
    final repository = build(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(meJson(roles: const ['SUPER_ADMIN'])),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await repository.restoreSession();

    expect(result.status, SessionStatus.signedIn);
    expect(result.user!.roles, contains('SUPER_ADMIN'));
  });

  test(
    'cierra la sesion cuando el token es invalido y no puede renovarse',
    () async {
      sessionManager.data = storedSession();
      final repository = build(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
        }),
        refreshFails: () => true,
      );

      final result = await repository.restoreSession();

      expect(result.status, SessionStatus.signedOut);
      expect(sessionManager.data, isNull);
    },
  );

  test('token expirado sin refresh posible cierra la sesion', () async {
    sessionManager.data = storedSession(
      expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final repository = build(
      httpClient: MockClient((request) async {
        fail('no deberia llamarse a la API sin token renovado');
      }),
      refreshFails: () => true,
    );

    final result = await repository.restoreSession();

    expect(result.status, SessionStatus.signedOut);
  });
}
