import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/shimmer_loading.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/users/application/use_cases/update_user.dart';
import 'package:tu_vacuna_pai/features/users/domain/entities/vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/repositories/users_repository.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/create_vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/list_users.dart';
import 'package:tu_vacuna_pai/features/users/presentation/pages/users_page.dart';
import 'package:tu_vacuna_pai/features/users/presentation/users_controller.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['USER_MANAGE'],
  );

  testWidgets('UsersPage muestra skeleton shimmer mientras carga vacunadores y luego muestra el listado', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final completer = Completer<List<Vaccinator>>();
    final repo = _AsyncUsersRepository(completer);

    final controller = UsersController(
      sessionManager: FakeSessionManager('token-123'),
      createVaccinator: CreateVaccinator(repo),
      listUsers: ListUsers(repo),
      updateUser: UpdateUser(repo),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UsersPage(
            controller: controller,
            institutionId: 'inst-1',
            offline: online,
          ),
        ),
      ),
    );

    // 1. Estado de carga inicial: debe mostrar ShimmerLoading con 5 skeleton tiles
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ShimmerLoading), findsOneWidget);
    expect(find.byKey(const ValueKey('users_skeleton')), findsOneWidget);

    // 2. Resolver la carga de usuarios
    completer.complete([
      const Vaccinator(
        id: 'u-1',
        email: 'ana.lopez@hospital.gov.co',
        fullName: 'Dra. Ana Lopez',
        institutionId: 'inst-1',
        roles: ['VACCINATOR'],
        status: 'ACTIVE',
        documentType: 'CC',
        documentNumber: '1098765432',
      ),
      const Vaccinator(
        id: 'u-2',
        email: 'carlos.ruiz@hospital.gov.co',
        fullName: 'Enf. Carlos Ruiz',
        institutionId: 'inst-1',
        roles: ['VACCINATOR'],
        status: 'INACTIVE',
        documentType: 'CC',
        documentNumber: '55667788',
      ),
    ]);

    // 3. Animar transición (AnimatedSwitcher 300ms)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Skeleton desaparece y se muestra la lista real
    expect(find.byKey(const ValueKey('users_skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('loaded_users')), findsOneWidget);
    expect(find.text('Dra. Ana Lopez'), findsOneWidget);
    expect(find.text('Enf. Carlos Ruiz'), findsOneWidget);
    expect(find.text('CC 1098765432 · ana.lopez@hospital.gov.co'), findsOneWidget);
    expect(find.text('ACTIVO'), findsOneWidget);
    expect(find.text('INACTIVO'), findsOneWidget);
  });
}

class _AsyncUsersRepository implements UsersRepository {
  _AsyncUsersRepository(this.completer);

  final Completer<List<Vaccinator>> completer;

  @override
  Future<List<Vaccinator>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) {
    return completer.future;
  }

  @override
  Future<Vaccinator> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
    required String operationId,
    required String documentType,
    required String documentNumber,
    String? phone,
    String? birthDate,
    String? gender,
    required String professionCode,
    String? professionalRegistrationNumber,
    String? professionalRegistrationType,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Vaccinator> updateRoles(
    String accessToken, {
    required String userId,
    required List<String> roles,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Vaccinator> updateStatus(
    String accessToken, {
    required String userId,
    required String status,
  }) async {
    throw UnimplementedError();
  }
}
