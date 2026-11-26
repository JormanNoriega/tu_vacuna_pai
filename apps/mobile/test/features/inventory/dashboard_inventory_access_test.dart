import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/delivery_detail_page.dart';

import 'inventory_page_test.dart' show FakeInventoryController;

AuthUser _user(List<String> roles, List<String> permissions) => AuthUser(
  id: 'u',
  email: 'u@example.test',
  name: 'Usuario',
  institution: const InstitutionProfile(
    id: 'i',
    code: 'I',
    name: 'Institución',
  ),
  roles: roles,
  permissions: permissions,
  offlineWindowHours: 72,
  lastOnlineValidation: DateTime.now(),
);

void main() {
  testWidgets(
    'admin con escritura ve acciones y sin controlador no se ofrecen accesos',
    (tester) async {
      final user = _user(
        ['ADMIN_INSTITUTION'],
        ['USER_MANAGE', 'INVENTORY_READ', 'INVENTORY_WRITE'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            user: user,
            onSignOut: () {},
            inventoryController: FakeInventoryController(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find
          .descendant(
            of: find.byType(DashboardPage),
            matching: find.text('Entregas'),
          )
          .first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Nueva entrega'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-nav-bar')), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('dashboard-nav-bar')),
          matching: find.text('Inicio'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(user: user, onSignOut: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jornadas'), findsNothing);
    },
  );
  testWidgets(
    'admin autorizado abre cada acceso en su sección y sin permiso de escritura no entrega',
    (tester) async {
      final c = FakeInventoryController();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            user: _user(
              ['ADMIN_INSTITUTION'],
              ['USER_MANAGE', 'INVENTORY_READ'],
            ),
            onSignOut: () {},
            inventoryController: c,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Jornadas', 'Entregas', 'Custodia y cierre']) {
        final action = find.text(label).first;
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          find.text(switch (label) {
            'Jornadas' => 'Organiza una jornada',
            'Entregas' => 'Entrega vacunas',
            _ => 'Seguimiento después de entregar',
          }),
          findsOneWidget,
        );
        expect(find.text('Nueva jornada'), findsNothing);
        expect(find.text('Nueva entrega'), findsNothing);
        if (label == 'Custodia y cierre') {
          await tester.pageBack();
        } else {
          expect(find.byKey(const Key('dashboard-nav-bar')), findsOneWidget);
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('dashboard-nav-bar')),
              matching: find.text('Inicio'),
            ),
          );
        }
        await tester.pumpAndSettle();
      }
    },
  );

  for (final roles in [
    ['VACCINATOR'],
    ['ADMIN_INSTITUTION', 'VACCINATOR'],
    ['ADMIN_INSTITUTION'],
  ]) {
    testWidgets(
      'no muestra accesos administrativos sin rol y permiso válidos: $roles',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: _user(
                roles,
                roles.length == 1 && roles.first == 'ADMIN_INSTITUTION'
                    ? ['USER_MANAGE']
                    : ['ATTENTION_CREATE', 'INVENTORY_READ', 'INVENTORY_WRITE'],
              ),
              onSignOut: () {},
              inventoryController: FakeInventoryController(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(GridView),
            matching: find.text('Entregas'),
          ),
          findsNothing,
        );
        expect(find.text('Jornadas'), findsNothing);
        expect(find.text('Custodia y cierre'), findsNothing);
      },
    );
  }

  testWidgets(
    'admin ve quién confirma recepción pero no puede recibir por destinatario',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryDetailPage(
            controller: FakeInventoryController(),
            institutionId: 'i',
            assignment: const {
              'id': 'a',
              'status': 'IN_TRANSIT',
              'vaccineName': 'Vacuna',
              'lotNumber': 'L',
              'vialCount': 2,
            },
            admin: true,
            canWrite: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Siguiente paso: recepción del vacunador'),
        findsOneWidget,
      );
      expect(find.text('Confirmar recepción'), findsNothing);
    },
  );
}
