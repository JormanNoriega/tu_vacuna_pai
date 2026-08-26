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
import 'package:tu_vacuna_pai/features/users/domain/use_cases/create_vaccinator.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/list_users.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/update_user_roles.dart';
import 'package:tu_vacuna_pai/features/users/domain/use_cases/update_user_status.dart';
import 'package:tu_vacuna_pai/features/users/presentation/users_controller.dart';
import 'package:tu_vacuna_pai/features/users/domain/entities/vaccinator.dart';

import 'features/admin/fake_admin_repository.dart';
import 'features/users/fake_users_repository.dart';

void main() {
  testWidgets('muestra login sin registro publico', (tester) async {
    await tester.pumpWidget(const TuVacunaApp());
    // La restauracion de sesion termina sin sesion persistida y muestra login.
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.textContaining('No hay registro publico'), findsOneWidget);
  });

  testWidgets('permite iniciar sesion y muestra el dashboard', (tester) async {
    await tester.pumpWidget(const TuVacunaApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@tuvacunapai.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'demo123');
    await tester.tap(find.text('Iniciar sesion'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

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

  testWidgets('ADMIN_INSTITUTION gestiona los vacunadores de su institucion',
      (tester) async {
    final usersController = UsersController(
      sessionManager: FakeSessionManager('token-123'),
      createVaccinator: CreateVaccinator(FakeUsersRepository()),
      listUsers: ListUsers(FakeUsersRepository()),
      updateUserStatus: UpdateUserStatus(FakeUsersRepository()),
      updateUserRoles: UpdateUserRoles(FakeUsersRepository()),
    );
    final user = AuthUser(
      id: 'admin-1',
      email: 'admin@hosp-a.com',
      name: 'Admin Hospital A',
      institution: const InstitutionProfile(
        id: 'inst-1',
        code: 'HOSP-A',
        name: 'Hospital A',
      ),
      roles: const ['ADMIN_INSTITUTION'],
      permissions: const ['USER_MANAGE', 'PATIENT_READ'],
      offlineWindowHours: 72,
      lastOnlineValidation: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: user,
          onSignOut: () {},
          usersController: usersController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navegar a la pestaña Administracion muestra la gestion de usuarios.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Administracion'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gestion de usuarios'), findsOneWidget);
    expect(find.text('Crear vacunador'), findsWidgets);
    expect(
      find.text('Todavia no hay vacunadores en esta institucion.'),
      findsOneWidget,
    );
  });

  testWidgets('VACCINATOR ve sus opciones sin seccion de administracion',
      (tester) async {
    final user = AuthUser(
      id: 'vac-1',
      email: 'vacunador@hosp-a.com',
      name: 'Ana Vacunadora',
      institution: const InstitutionProfile(
        id: 'inst-1',
        code: 'HOSP-A',
        name: 'Hospital A',
      ),
      roles: const ['VACCINATOR'],
      permissions: const ['PATIENT_READ', 'ATTENTION_CREATE', 'ATTENTION_READ'],
      offlineWindowHours: 72,
      lastOnlineValidation: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(user: user, onSignOut: () {})),
    );
    await tester.pumpAndSettle();

    // Ve la barra operativa de vacunador y sus destinos.
    expect(find.text('Buenos dias'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Nueva atencion'), findsWidgets);
    expect(find.text('Historial'), findsOneWidget);
    // No ve administracion de usuarios ni inventario.
    expect(find.text('Administracion'), findsNothing);
    expect(find.text('Inventario'), findsNothing);
  });

  testWidgets('ADMIN_INSTITUTION edita el estado y los roles de un vacunador',
      (tester) async {
    final repository = FakeUsersRepository();
    repository.users.add(
      Vaccinator(
        id: 'vac-1',
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        institutionId: 'inst-1',
        roles: const ['VACCINATOR'],
        status: 'ACTIVE',
      ),
    );
    final usersController = UsersController(
      sessionManager: FakeSessionManager('token-123'),
      createVaccinator: CreateVaccinator(repository),
      listUsers: ListUsers(repository),
      updateUserStatus: UpdateUserStatus(repository),
      updateUserRoles: UpdateUserRoles(repository),
    );
    final user = AuthUser(
      id: 'admin-1',
      email: 'admin@hosp-a.com',
      name: 'Admin Hospital A',
      institution: const InstitutionProfile(
        id: 'inst-1',
        code: 'HOSP-A',
        name: 'Hospital A',
      ),
      roles: const ['ADMIN_INSTITUTION'],
      permissions: const ['USER_MANAGE', 'PATIENT_READ'],
      offlineWindowHours: 72,
      lastOnlineValidation: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: user,
          onSignOut: () {},
          usersController: usersController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Administracion'),
      ),
    );
    await tester.pumpAndSettle();

    // Abrir la edicion del vacunador.
    await tester.tap(find.byTooltip('Editar usuario'));
    await tester.pumpAndSettle();
    expect(find.text('Editar Ana Vacunadora'), findsOneWidget);

    // Desactivar y cambiar a solo lectura.
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Solo lectura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario actualizado correctamente.'), findsOneWidget);
    expect(find.text('INACTIVO'), findsOneWidget);
  });

  testWidgets('muestra el banner de solo lectura cuando la ventana vencio',
      (tester) async {
    final user = AuthUser(
      id: 'vac-1',
      email: 'vacunador@hosp-a.com',
      name: 'Ana Vacunadora',
      institution: const InstitutionProfile(
        id: 'inst-1',
        code: 'HOSP-A',
        name: 'Hospital A',
      ),
      roles: const ['VACCINATOR'],
      permissions: const ['PATIENT_READ', 'ATTENTION_CREATE'],
      offlineWindowHours: 72,
      lastOnlineValidation: DateTime.now().subtract(const Duration(hours: 100)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: user,
          onSignOut: () {},
          offlineLocked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modo solo lectura'), findsOneWidget);
    expect(
      find.textContaining('La ventana offline vencio'),
      findsOneWidget,
    );
  });
}
