import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution_admin.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/list_institutions.dart';
import 'package:tu_vacuna_pai/features/admin/presentation/admin_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';

import 'fake_admin_repository.dart';

void main() {
  late FakeAdminRepository repository;
  late FakeSessionManager sessionManager;
  late AdminController controller;

  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['INSTITUTION_WRITE', 'USER_MANAGE'],
  );

  AdminController build() => AdminController(
    sessionManager: sessionManager,
    createInstitution: CreateInstitution(repository),
    listInstitutions: ListInstitutions(repository),
    createInstitutionAdmin: CreateInstitutionAdmin(repository),
  );

  setUp(() {
    repository = FakeAdminRepository();
    sessionManager = FakeSessionManager('token-123');
    controller = build();
  });

  group('AdminController', () {
    test('crea una institucion y la agrega a la lista', () async {
      final created = await controller.createInstitution(
        offline: online,
        code: 'HOSP-A',
        name: 'Hospital A',
      );

      expect(created, isNotNull);
      expect(created!.code, 'HOSP-A');
      expect(controller.institutions, hasLength(1));
      expect(controller.error, isNull);
    });

    test(
      'mantiene la contrasena temporal sin exponerla en el estado',
      () async {
        final created = await controller.createInstitutionAdmin(
          offline: online,
          email: 'admin@hosp-a.com',
          fullName: 'Admin A',
          institutionId: 'inst-1',
          temporaryPassword: 'Secreto123!',
        );

        expect(created, isNotNull);
        expect(repository.lastPassword, 'Secreto123!');
        // El controlador no guarda la contrasena en ningun campo publico.
        expect(controller.error, isNull);
      },
    );

    test('registra error cuando el repositorio falla', () async {
      repository = FakeAdminRepository(failOnCreate: true);
      controller = build();

      final created = await controller.createInstitution(
        offline: online,
        code: 'HOSP-A',
        name: 'Hospital A',
      );

      expect(created, isNull);
      expect(controller.error, isNotNull);
    });

    test('expone error de sesion expirada cuando no hay token', () async {
      sessionManager = FakeSessionManager(null);
      controller = build();

      final created = await controller.createInstitution(
        offline: online,
        code: 'X',
        name: 'Y',
      );

      expect(created, isNull);
      expect(controller.error, contains('sesion expiro'));
    });

    test('carga instituciones al iniciar', () async {
      repository.institutions.add(_institution());

      await controller.loadInstitutions();

      expect(controller.institutions, hasLength(1));
      expect(controller.isLoading, isFalse);
    });

    test('bloquea las escrituras cuando la ventana offline vencio', () async {
      const locked = OfflineAccess(
        status: SessionStatus.offlineLocked,
        permissions: ['INSTITUTION_WRITE', 'USER_MANAGE'],
      );

      final created = await controller.createInstitution(
        offline: locked,
        code: 'HOSP-A',
        name: 'Hospital A',
      );

      expect(created, isNull);
      expect(controller.error, contains('ventana offline vencio'));
      expect(controller.institutions, isEmpty);
    });

    test(
      'bloquea operaciones online-first en modo offline autorizado',
      () async {
        const offline = OfflineAccess(
          status: SessionStatus.offlineAuthorized,
          permissions: ['INSTITUTION_WRITE', 'USER_MANAGE'],
        );

        final created = await controller.createInstitutionAdmin(
          offline: offline,
          email: 'admin@hosp-a.com',
          fullName: 'Admin A',
          institutionId: 'inst-1',
          temporaryPassword: 'Secreto123!',
        );

        expect(created, isNull);
        expect(controller.error, contains('requiere conexion'));
      },
    );
  });
}

Institution _institution() => Institution(
  id: 'inst-1',
  code: 'HOSP-A',
  name: 'Hospital A',
  status: 'ACTIVE',
  offlineWindowHours: 72,
);
