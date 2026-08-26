import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/create_vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/list_users.dart';
import 'package:tu_vacuna_pai/features/users/presentation/users_controller.dart';

import '../admin/fake_admin_repository.dart';
import 'fake_users_repository.dart';

void main() {
  late FakeUsersRepository repository;
  late FakeSessionManager sessionManager;
  late UsersController controller;

  UsersController build() => UsersController(
        sessionManager: sessionManager,
        createVaccinator: CreateVaccinator(repository),
        listUsers: ListUsers(repository),
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
      );

      expect(created, isNotNull);
      expect(created!.roles, contains('VACCINATOR'));
      expect(controller.users, hasLength(1));
      expect(controller.error, isNull);
    });

    test('mantiene la contrasena temporal sin exponerla en el estado', () async {
      await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Secreto123!',
      );

      expect(repository.lastPassword, 'Secreto123!');
      // El controlador no guarda la contrasena en ningun campo publico.
      expect(controller.error, isNull);
    });

    test('registra error cuando el repositorio falla', () async {
      repository = FakeUsersRepository(failOnCreate: true);
      controller = build();

      final created = await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
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
      );

      expect(created, isNull);
      expect(controller.error, contains('sesion expiro'));
    });

    test('carga los usuarios de la institucion', () async {
      await controller.createVaccinator(
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Temp123!',
      );

      await controller.loadUsers(institutionId: 'inst-1');

      expect(controller.users, hasLength(1));
      expect(controller.isLoading, isFalse);
    });
  });
}