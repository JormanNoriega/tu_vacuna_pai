import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/widgets/admin_web_sidebar.dart';
import 'package:tu_vacuna_pai/features/geography/geography_controller.dart';

AuthUser user(List<String> roles) => AuthUser(
  id: 'user', email: 'u@example.test', name: 'Usuario',
  institution: const InstitutionProfile(id: 'i', code: 'i', name: 'Institución'),
  roles: roles, permissions: const ['ATTENTION_READ'],
  offlineWindowHours: 72, lastOnlineValidation: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [390.0]) {
    testWidgets('acceso institucional en ancho $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = GeographyController(
        api: ApiClient(baseUrl: 'https://example.test/api/v1'),
        sessionManager: SessionManager(const FlutterSecureStorage()),
      );
      await tester.pumpWidget(MaterialApp(home: DashboardPage(
        user: user(['ADMIN_INSTITUTION']), onSignOut: () {},
        geographyController: controller, sessionStatus: SessionStatus.offlineAuthorized,
      )));
      await tester.pumpAndSettle();
      if (width < 960) {
        await tester.tap(find.byTooltip('Visor geográfico'));
      } else {
        await tester.tap(find.byIcon(Icons.map_outlined).first);
      }
      await tester.pumpAndSettle();
      expect(find.text('El visor requiere una sesión y conexión en línea.'), findsOneWidget);
    });
  }

  testWidgets('menú web abre la sección geográfica', (tester) async {
    String? section;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminWebSidebar(
      selectedSection: 'inicio', onSelectSection: (value) => section = value,
      onAction: (_) {}, onSignOut: () {}, userName: 'Usuario',
      institutionName: 'Institución', showGeography: true,
    ))));
    await tester.tap(find.byIcon(Icons.map_outlined));
    expect(section, 'geografia');
  });

  for (final roles in [
    ['VACCINATOR'],
    ['ADMIN_INSTITUTION', 'VACCINATOR'],
    ['SUPER_ADMIN', 'ADMIN_INSTITUTION'],
  ]) {
    testWidgets('oculta acceso para $roles', (tester) async {
      await tester.pumpWidget(MaterialApp(home: DashboardPage(
        user: user(roles), onSignOut: () {},
        geographyController: GeographyController(
          api: ApiClient(baseUrl: 'https://example.test/api/v1'),
          sessionManager: SessionManager(const FlutterSecureStorage()),
        ),
      )));
      await tester.pump();
      expect(find.byTooltip('Visor geográfico'), findsNothing);
    });
  }
}
