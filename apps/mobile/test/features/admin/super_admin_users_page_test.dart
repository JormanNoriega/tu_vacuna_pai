import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/shimmer_loading.dart';
import 'package:tu_vacuna_pai/features/admin/application/use_cases/list_institution_admins.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/clone_catalog_result.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/institution_admin.dart';
import 'package:tu_vacuna_pai/features/admin/domain/repositories/admin_repository.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution_admin.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/list_institutions.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/update_institution_config.dart';
import 'package:tu_vacuna_pai/features/admin/presentation/admin_controller.dart';
import 'package:tu_vacuna_pai/features/admin/presentation/pages/super_admin_users_page.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';

import 'fake_admin_repository.dart';

void main() {
  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['USER_MANAGE'],
  );

  testWidgets('SuperAdminUsersPage muestra Skeleton Shimmer mientras carga y luego muestra administradores por institucion', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final completer = Completer<List<InstitutionAdmin>>();
    final repo = _AsyncAdminRepository(completer);
    final listInst = ListInstitutions(repo);

    final controller = AdminController(
      sessionManager: FakeSessionManager('token-123'),
      createInstitution: CreateInstitution(repo),
      listInstitutions: listInst,
      createInstitutionAdmin: CreateInstitutionAdmin(repo),
      updateInstitutionConfig: UpdateInstitutionConfig(repo),
      listInstitutionAdmins: ListInstitutionAdmins(
        repository: repo,
        listInstitutions: listInst,
      ),
    );

    // Precargar las instituciones para que controller.institutions no este vacio
    await controller.loadInstitutions();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperAdminUsersPage(
            controller: controller,
            offline: online,
          ),
        ),
      ),
    );

    // 1. Estado de carga inicial: debe mostrar ShimmerLoading con la silueta de instituciones y administradores
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ShimmerLoading), findsOneWidget);
    expect(find.byKey(const ValueKey('super_admin_users_skeleton')), findsOneWidget);

    // 2. Resolver la carga de admins
    completer.complete([
      const InstitutionAdmin(
        id: 'admin-1',
        email: 'carlos@hospital.gov.co',
        fullName: 'Carlos Gomez',
        institutionId: 'inst-1',
        roles: ['ADMIN_INSTITUTION'],
      ),
    ]);

    // 3. Animar transición (AnimatedSwitcher 300ms)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Skeleton desaparece y se muestra el listado real agrupado por institución
    expect(find.byKey(const ValueKey('super_admin_users_skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('loaded_admins')), findsOneWidget);
    expect(find.text('Hospital Central'), findsOneWidget);
    expect(find.text('Carlos Gomez'), findsOneWidget);
    expect(find.text('carlos@hospital.gov.co'), findsOneWidget);
    expect(find.text('ADMIN_INSTITUTION'), findsOneWidget);
  });
}

class _AsyncAdminRepository implements AdminRepository {
  _AsyncAdminRepository(this.completer);

  final Completer<List<InstitutionAdmin>> completer;

  final institutions = [
    const Institution(
      id: 'inst-1',
      code: 'HOSP-1',
      name: 'Hospital Central',
      status: 'ACTIVE',
      offlineWindowHours: 72,
    ),
  ];

  @override
  Future<List<Institution>> listInstitutions(String accessToken) async => institutions;

  @override
  Future<List<InstitutionAdmin>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) {
    return completer.future;
  }

  @override
  Future<Institution> createInstitution(
    String accessToken, {
    required String code,
    required String name,
    int? offlineWindowHours,
  }) async => throw UnimplementedError();

  @override
  Future<InstitutionAdmin> createInstitutionAdmin(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
    required String operationId,
  }) async => throw UnimplementedError();

  @override
  Future<Institution> updateInstitutionConfig(
    String accessToken, {
    required String institutionId,
    required int offlineWindowHours,
  }) async => throw UnimplementedError();

  @override
  Future<CloneCatalogResult> cloneCatalogToInstitution(
    String accessToken, {
    required String institutionId,
    required bool includeDefaultConfig,
  }) async => throw UnimplementedError();
}
