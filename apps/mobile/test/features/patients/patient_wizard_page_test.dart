import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/attention_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/create_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/search_patient.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/pages/patient_wizard_page.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  const offline = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['PATIENT_WRITE', 'ATTENTION_CREATE', 'ATTENTION_READ'],
  );

  Future<void> openWizard(WidgetTester tester) async {
    final controller = AttentionController(
      sessionManager: FakeSessionManager('token-123'),
      searchPatient: SearchPatient(_UnusedPatientsRepository()),
      createPatient: CreatePatient(_UnusedPatientsRepository()),
      listEffectiveCatalog: ListEffectiveCatalog(_UnusedCatalogRepository()),
      listCountries: ListCountries(_UnusedCatalogRepository()),
      listDepartments: ListDepartments(_UnusedCatalogRepository()),
      listMunicipalities: ListMunicipalities(_UnusedCatalogRepository()),
      listReferenceCatalogs: ListReferenceCatalogs(
        _UnusedCatalogRepository(),
      ),
      createAttention: CreateAttention(_UnusedAttentionsRepository()),
      updateAttention: UpdateAttention(_UnusedAttentionsRepository()),
      registerDose: RegisterDose(_UnusedAttentionsRepository()),
      completeAttention: CompleteAttention(_UnusedAttentionsRepository()),
      cancelAttention: CancelAttention(_UnusedAttentionsRepository()),
      cancelDose: CancelDose(_UnusedAttentionsRepository()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientWizardPage(
                      controller: controller,
                      offline: offline,
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('pide confirmacion al volver con datos ingresados', (
    tester,
  ) async {
    await openWizard(tester);

    await tester.enterText(find.byType(TextFormField).at(1), 'Ana');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Descartar cambios'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar cambios'), findsNothing);
    expect(find.byType(PatientWizardPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientWizardPage), findsNothing);
  });

  testWidgets('vuelve sin confirmar cuando no hay datos', (tester) async {
    await openWizard(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Descartar cambios'), findsNothing);
    expect(find.byType(PatientWizardPage), findsNothing);
  });
}

class _UnusedPatientsRepository implements PatientsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No usado en el test');
}

class _UnusedAttentionsRepository implements AttentionsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No usado en el test');
}

class _UnusedCatalogRepository implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No usado en el test');
}
