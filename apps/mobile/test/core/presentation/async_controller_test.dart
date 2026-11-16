import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_policy.dart';
import 'package:tu_vacuna_pai/core/network/api_exception.dart';
import 'package:tu_vacuna_pai/core/presentation/async_controller.dart';

import '../../features/admin/fake_admin_repository.dart'
    show FakeSessionManager;

class _Controller extends AsyncController {
  _Controller({required super.sessionManager});

  final List<String> executedTokens = [];

  Future<void> run() => execute((token) async {
    executedTokens.add(token);
  });

  Future<void> runThatThrows() => execute((_) async {
    throw const ApiException('boom', statusCode: 500);
  });

  Future<void> runAwaiting(Future<void> gate) => execute((token) async {
    executedTokens.add(token);
    await gate;
  });

  @override
  String mapApiError(ApiException e) =>
      e.statusCode == 409 ? 'conflicto' : e.message;
}

class _OfflineFailingController extends AsyncController {
  _OfflineFailingController({required super.sessionManager});

  Future<void> run() => execute((_) async {
    throw const OfflineOperationNotAuthorizedException();
  });
}

void main() {
  group('AsyncController', () {
    test('ejecuta la accion con el token de sesion', () async {
      final c = _Controller(sessionManager: FakeSessionManager('token-abc'));
      await c.run();
      expect(c.executedTokens, ['token-abc']);
      expect(c.isLoading, isFalse);
      expect(c.error, isNull);
    });

    test('expone error de sesion expirada sin ejecutar la accion', () async {
      final c = _Controller(sessionManager: FakeSessionManager(null));
      await c.run();
      expect(c.executedTokens, isEmpty);
      expect(c.error, contains('sesion expiro'));
      expect(c.isLoading, isFalse);
    });

    test('mapea ApiException con el hook por feature', () async {
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      await c.runThatThrows();
      expect(c.error, 'boom');
      expect(c.isLoading, isFalse);
    });

    test('mapea excepciones de politica offline', () async {
      final c = _OfflineFailingController(
        sessionManager: FakeSessionManager('t'),
      );
      await c.run();
      expect(c.error, contains('requiere conexion'));
    });

    test('clearError limpia el error y notifica', () async {
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      await c.runThatThrows();
      expect(c.error, isNotNull);
      c.clearError();
      expect(c.error, isNull);
    });

    test('setError fija un error sin pasar por execute', () async {
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      c.setError('validacion offline');
      expect(c.error, 'validacion offline');
    });

    test('una respuesta tardia tras dispose no notifica ni lanza', () async {
      final gate = Completer<void>();
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      final pending = c.runAwaiting(gate.future);
      c.dispose();
      expect(c.isDisposed, isTrue);

      gate.complete();
      await expectLater(pending, completes);
      expect(c.isLoading, isFalse);
      expect(c.executedTokens, ['t']);
    });

    test('dispose es idempotente', () {
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      c.dispose();
      expect(c.dispose, returnsNormally);
    });

    test('no inicia nuevas ejecuciones tras dispose', () async {
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      c.dispose();
      await expectLater(c.run(), completes);
      expect(c.executedTokens, isEmpty);
      expect(c.isLoading, isFalse);
    });

    test('setError y clearError tras dispose no lanzan', () {
      final c = _Controller(sessionManager: FakeSessionManager('t'));
      c.dispose();
      expect(() => c.setError('tarde'), returnsNormally);
      expect(() => c.clearError(), returnsNormally);
    });
  });
}
