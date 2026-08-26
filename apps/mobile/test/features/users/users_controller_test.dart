import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/create_vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/list_users.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/update_user_roles.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/update_user_status.dart';
import 'package:tu_vacuna_pai/features/users/presentation/users_controller.dart';

import '../admin/fake_admin_repository.dart';
import 'fake_users_repository.dart';

void main() {
  late FakeUsersRepository repository;
  late FakeSessionManager sessionManager;
  late UsersController controller;

  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['USER_MANAGE'],
  );

  UsersController build() => UsersController(
    sessionManager: sessionManager,
    createVaccinator: CreateVaccinator(repository),
    listUsers: ListUsers(repository),
    updateUserStatus: UpdateUserStatus(repository),
    updateUserRoles: UpdateUserRoles(repository),
  );

  setUp(() {
    repository = FakeUsersRepository();
    sessionManager = FakeSessionManager('token-123');
    controller = build();
  });

  group('UsersController', () {
    test('crea un vacunador y lo agrega a la lista', () async {
      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );

      expect(created, isNotNull);
      expect(created!.roles, contains('VACCINATOR'));
      expect(controller.users, hasLength(1));
      expect(controller.error, isNull);
    });

    test(
      'mantiene la contrasena temporal sin exponerla en el estado',
      () async {
        await controller.createVaccinator(
          email: 'vacunador@hosp-a.com',
          fullName: 'Ana Vacunadora',
          temporaryPassword: 'Secreto123!',
          offline: online,
        );

        expect(repository.lastPassword, 'Secreto123!');
        // El controlador no guarda la contrasena en ningun campo publico.
        expect(controller.error, isNull);
      },
    );

    test('registra error cuando el repositorio falla', () async {
      repository = FakeUsersRepository(failOnCreate: true);
      controller = build();

      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );

      expect(created, isNull);
      expect(controller.error, isNotNull);
    });

    test('expone error de sesion expirada cuando no hay token', () async {
      sessionManager = FakeSessionManager(null);
      controller = build();

      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );

      expect(created, isNull);
      expect(controller.error, contains('sesion expiro'));
    });

    test('carga los usuarios de la institucion', () async {
      await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );

      await controller.loadUsers(institutionId: 'inst-1');

      expect(controller.users, hasLength(1));
      expect(controller.isLoading, isFalse);
    });

    test('actualiza el estado y los roles de un usuario', () async {
      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );
      await controller.loadUsers(institutionId: 'inst-1');

      final saved = await controller.updateUser(
        created!,
        offline: online,
        status: 'INACTIVE',
        roles: const ['READ_ONLY'],
      );

      expect(saved, isTrue);
      final updated = controller.users.single;
      expect(updated.status, 'INACTIVE');
      expect(updated.roles, ['READ_ONLY']);
      expect(controller.error, isNull);
    });

    test('mantiene el estado anterior cuando la edicion falla', () async {
      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );
      await controller.loadUsers(institutionId: 'inst-1');

      repository.failOnUpdate = true;
      final saved = await controller.updateUser(
        created!,
        offline: online,
        status: 'INACTIVE',
        roles: const ['READ_ONLY'],
      );

      expect(saved, isFalse);
      expect(controller.users.single.status, 'ACTIVE');
      expect(controller.users.single.roles, ['VACCINATOR']);
    });

    test('bloquea las escrituras cuando la ventana offline vencio', () async {
      const locked = OfflineAccess(
        status: SessionStatus.offlineLocked,
        permissions: ['USER_MANAGE'],
      );

      final created = await controller.createVaccinator(
        offline: locked,
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
      );

      expect(created, isNull);
      expect(controller.error, contains('ventana offline vencio'));
      expect(controller.users, isEmpty);
    });

    test('bloquea la edicion cuando la ventana offline vencio', () async {
      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
        offline: online,
      );
      await controller.loadUsers(institutionId: 'inst-1');

      const locked = OfflineAccess(
        status: SessionStatus.offlineLocked,
        permissions: ['USER_MANAGE'],
      );
      final saved = await controller.updateUser(
        created!,
        offline: locked,
        status: 'INACTIVE',
        roles: const ['READ_ONLY'],
      );

      expect(saved, isFalse);
      expect(controller.users.single.status, 'ACTIVE');
    });

    test(
      'bloquea operaciones online-first en modo offline autorizado',
      () async {
        const offline = OfflineAccess(
          status: SessionStatus.offlineAuthorized,
          permissions: ['USER_MANAGE'],
        );

        final created = await controller.createVaccinator(
          offline: offline,
          email: 'vacunador@hosp-a.com',
          fullName: 'Ana Vacunadora',
          temporaryPassword: 'Temp123!',
        );

        expect(created, isNull);
        expect(controller.error, contains('requiere conexion'));
      },
    );

    test('rechaza una escritura sin el permiso requerido', () async {
      const withoutPermission = OfflineAccess(
        status: SessionStatus.signedIn,
        permissions: ['PATIENT_READ'],
      );

      final created = await controller.createVaccinator(
        offline: withoutPermission,
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
      );

      expect(created, isNull);
      expect(controller.error, contains('No tienes permiso'));
    });
  });
}
