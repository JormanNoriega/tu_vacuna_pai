import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_exception.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/auth/domain/use_cases/restore_session.dart';
import 'package:tu_vacuna_pai/features/auth/domain/use_cases/sign_in.dart';
import 'package:tu_vacuna_pai/features/auth/domain/use_cases/sign_out.dart';
import 'package:tu_vacuna_pai/features/auth/presentation/auth_controller.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late AuthController controller;

  AuthController build() => AuthController(
    signIn: SignIn(repository),
    restoreSession: RestoreSession(repository),
    signOut: SignOut(repository),
  );

  setUp(() {
    repository = FakeAuthRepository();
    controller = build();
  });

  group('AuthController.restoreSession', () {
    test(
      'entra online con perfil fresco cuando la restauracion lo devuelve',
      () async {
        repository.restoreResult = SessionRestoreResult.signedIn(demoUser);

        await controller.restoreSession();

        expect(controller.isRestoring, isFalse);
        expect(controller.isAuthenticated, isTrue);
        expect(controller.isOfflineLocked, isFalse);
        expect(controller.user?.name, 'Ana Vacunadora');
      },
    );

    test(
      'entra en modo solo lectura cuando la ventana offline vencio',
      () async {
        repository.restoreResult = SessionRestoreResult.offlineLocked(demoUser);

        await controller.restoreSession();

        expect(controller.isAuthenticated, isTrue);
        expect(controller.isOfflineLocked, isTrue);
        expect(repository.restoreCalls, 1);
      },
    );

    test('entra en modo offline autorizado dentro de la ventana', () async {
      repository.restoreResult = SessionRestoreResult.offlineAuthorized(
        demoUser,
      );

      await controller.restoreSession();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.isOfflineLocked, isFalse);
      expect(controller.isOfflineAuthorized, isTrue);
      expect(controller.status, SessionStatus.offlineAuthorized);
    });

    test('sin sesion persistida termina en signedOut', () async {
      repository.restoreResult = SessionRestoreResult.signedOut();

      await controller.restoreSession();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.isOfflineLocked, isFalse);
      expect(controller.status, SessionStatus.signedOut);
    });

    test(
      'un fallo de restauracion cae a signedOut sin colgar la app',
      () async {
        final controller = AuthController(
          signIn: SignIn(repository),
          restoreSession: _ThrowingRestore(repository),
          signOut: SignOut(repository),
        );

        await controller.restoreSession();

        expect(controller.isRestoring, isFalse);
        expect(controller.isAuthenticated, isFalse);
      },
    );
  });

  group('AuthController.signOut', () {
    test('limpia el estado y notifica al repositorio', () async {
      repository.restoreResult = SessionRestoreResult.signedIn(demoUser);
      await controller.restoreSession();
      expect(controller.isAuthenticated, isTrue);

      await controller.signOut();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.status, SessionStatus.signedOut);
      expect(repository.signOutCalls, 1);
    });
  });

  group('AuthController.signIn', () {
    test('signIn exitoso marca la sesion como online', () async {
      final ok = await controller.signIn(
        email: 'vacunador@hosp-a.com',
        password: 'Temp123!',
      );

      expect(ok, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.status, SessionStatus.signedIn);
    });

    test('signIn fallido expone el error sin marcar sesion', () async {
      repository.signInError = const AuthException(
        'Correo o contrasena incorrectos.',
      );

      final ok = await controller.signIn(
        email: 'vacunador@hosp-a.com',
        password: 'mal',
      );

      expect(ok, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.error, contains('incorrectos'));
    });
  });
}

class _ThrowingRestore extends RestoreSession {
  _ThrowingRestore(super.repository);

  @override
  Future<SessionRestoreResult> call() async {
    throw StateError('boom');
  }
}
