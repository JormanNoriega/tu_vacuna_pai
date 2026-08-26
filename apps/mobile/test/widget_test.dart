import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/app/app.dart';
import 'package:tu_vacuna_pai/features/admin/domain/entities/institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution_admin.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/list_institutions.dart';
import 'package:tu_vacuna_pai/features/admin/presentation/admin_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/pages/dashboard_page.dart';

import 'features/admin/fake_admin_repository.dart';

void main() {
  testWidgets('muestra login sin registro publico', (tester) async {
    await tester.pumpWidget(const TuVacunaApp());

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.textContaining('No hay registro publico'), findsOneWidget);
  });

  testWidgets('permite iniciar sesion y muestra el dashboard', (tester) async {
    await tester.pumpWidget(const TuVacunaApp());

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@tuvacunapai.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'demo123');
    await tester.tap(find.text('Iniciar sesion'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Buenos dias'), findsOneWidget);
    expect(find.text('Todo esta sincronizado'), findsOneWidget);
    expect(find.text('Acciones frecuentes'), findsOneWidget);
  });

  testWidgets('SUPER_ADMIN ve la seccion de administracion con dos acciones',
      (tester) async {
    final repository = FakeAdminRepository();
    repository.institutions.add(
      Institution(
        id: 'inst-1',
        code: 'HOSP-A',
        name: 'Hospital A',
        status: 'ACTIVE',
        offlineWindowHours: 72,
      ),
    );
    final adminController = AdminController(
      sessionManager: FakeSessionManager('token-123'),
      createInstitution: CreateInstitution(repository),
      listInstitutions: ListInstitutions(repository),
      createInstitutionAdmin: CreateInstitutionAdmin(repository),
    );
    final user = AuthUser(
      id: 'super-1',
      email: 'super@pai.test',
      name: 'Super Admin',
      institution: const InstitutionProfile(
        id: 'inst-0',
        code: 'PAI-DEMO',
        name: 'Institucion Demo PAI',
      ),
      roles: const ['SUPER_ADMIN'],
      permissions: const ['INSTITUTION_WRITE', 'USER_MANAGE'],
      offlineWindowHours: 72,
      lastOnlineValidation: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: user,
          onSignOut: () {},
          adminController: adminController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administracion'), findsWidgets);
    expect(find.text('Crear institucion'), findsWidgets);
    expect(find.text('Crear usuario admin de institucion'), findsWidgets);
    // Las acciones genericas de vacunador no deben aparecer.
    expect(find.text('Nueva atencion'), findsNothing);
    expect(find.text('Acciones frecuentes'), findsNothing);
    // No hay barra de navegacion operativa para el SUPER_ADMIN.
    expect(find.byType(NavigationBar), findsNothing);
  });
}
