import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/core/network/api_exception.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_controller.dart';

class FakeSessionManager extends SessionManager {
  FakeSessionManager(this.data) : super(const FlutterSecureStorage());
  SessionData? data;

  @override
  Future<SessionData?> loadSession() async => data;
}

void main() {
  final controller = InventoryController(
    sessionManager: SessionManager(const FlutterSecureStorage()),
    api: ApiClient(baseUrl: 'http://localhost'),
  );

  test('explica una ruta de inventario no habilitada', () {
    final message = controller.mapApiError(
      const ApiException(
        'No static resource api/v1/institutions/id/inventory/lots.',
        statusCode: 404,
      ),
    );
    expect(message, contains('inventario no está disponible'));
    expect(message, isNot(contains('No static resource')));
  });

  test('distingue sesión y permisos', () {
    expect(
      controller.mapApiError(const ApiException('', statusCode: 401)),
      contains('sesión'),
    );
    expect(
      controller.mapApiError(const ApiException('', statusCode: 403)),
      contains('permiso'),
    );
    expect(
      controller.mapApiError(
        const ApiException('Lote no encontrado', statusCode: 404),
      ),
      'Lote no encontrado',
    );
  });

  test('renueva una sesión vencida antes de ejecutar la operación', () async {
    final now = DateTime.now();
    final sessions = FakeSessionManager(
      SessionData(
        accessToken: 'vencido',
        refreshToken: 'refresh',
        expiresAt: now.subtract(const Duration(minutes: 1)),
        lastOnlineValidation: now,
      ),
    );
    var renewals = 0;
    final inventory = InventoryController(
      sessionManager: sessions,
      api: ApiClient(baseUrl: 'http://localhost'),
      renewSession: () async {
        renewals++;
        sessions.data = SessionData(
          accessToken: 'nuevo',
          refreshToken: 'refresh',
          expiresAt: now.add(const Duration(hours: 1)),
          lastOnlineValidation: now,
        );
      },
    );
    String? usedToken;
    await inventory.execute((token) async {
      usedToken = token;
    });
    expect(renewals, 1);
    expect(usedToken, 'nuevo');
    await inventory.execute((token) async {});
    expect(renewals, 1);
  });
}
