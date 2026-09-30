import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/utils/field_input.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/create_institution_admin.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/list_institutions.dart';
import 'package:tu_vacuna_pai/features/admin/domain/use_cases/update_institution_config.dart';
import 'package:tu_vacuna_pai/features/admin/presentation/admin_controller.dart';
import 'package:tu_vacuna_pai/features/admin/presentation/pages/create_institution_page.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';

import 'fake_admin_repository.dart';

void main() {
  const offline = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['INSTITUTION_WRITE'],
  );

  Future<void> openPage(WidgetTester tester) async {
    final repository = FakeAdminRepository();
    final controller = AdminController(
      sessionManager: FakeSessionManager('token-123'),
      createInstitution: CreateInstitution(repository),
      listInstitutions: ListInstitutions(repository),
      createInstitutionAdmin: CreateInstitutionAdmin(repository),
      updateInstitutionConfig: UpdateInstitutionConfig(repository),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CreateInstitutionPage(controller: controller, offline: offline),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  testWidgets('limita el codigo y el nombre de la institucion', (tester) async {
    await openPage(tester);

    final codeField = find.byType(TextFormField).at(0);
    await tester.enterText(codeField, 'A' * 40);
    await tester.pump();
    expect(textOf(tester, codeField).length, FieldLimits.institutionCode);

    final nameField = find.byType(TextFormField).at(1);
    await tester.enterText(nameField, 'N' * 260);
    await tester.pump();
    expect(textOf(tester, nameField).length, FieldLimits.institutionName);
  });

  testWidgets('la ventana offline solo admite 3 digitos', (tester) async {
    await openPage(tester);

    final offlineField = find.byType(TextFormField).at(2);
    await tester.enterText(offlineField, '99x999');
    await tester.pump();
    expect(textOf(tester, offlineField), '999');
  });
}
