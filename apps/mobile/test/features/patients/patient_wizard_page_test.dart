import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/utils/document_rules.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/attention_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
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

  Future<void> openWizard(
    WidgetTester tester, {
    PatientsRepository? patients,
  }) async {
    final repository = patients ?? _UnusedPatientsRepository();
    final controller = AttentionController(
      sessionManager: FakeSessionManager('token-123'),
      searchPatient: SearchPatient(repository),
      createPatient: CreatePatient(repository),
      listEffectiveCatalog: ListEffectiveCatalog(_UnusedCatalogRepository()),
      listCountries: ListCountries(_UnusedCatalogRepository()),
      listDepartments: ListDepartments(_UnusedCatalogRepository()),
      listMunicipalities: ListMunicipalities(_UnusedCatalogRepository()),
      listReferenceCatalogs: ListReferenceCatalogs(_UnusedCatalogRepository()),
      listInsurers: ListInsurers(_UnusedCatalogRepository()),
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

  testWidgets('avisa si el documento ya esta registrado y permite usarlo', (
    tester,
  ) async {
    await openWizard(
      tester,
      patients: _FakePatientsRepository(const [
        Patient(
          id: 'p1',
          documentType: 'CC',
          documentNumber: '1003239695',
          firstName: 'Juan',
          lastName: 'Perez',
          birthDate: null,
          sex: 'MALE',
          status: 'ACTIVE',
        ),
      ]),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC - Cedula de Ciudadania').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '1003239695');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(2), 'Diaz');
    await tester.pump();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Paciente ya registrado'), findsOneWidget);

    await tester.tap(find.text('Usar este paciente'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientWizardPage), findsNothing);
  });

  testWidgets('el paso 1 exige tipo de documento, sexo y fecha de nacimiento', (
    tester,
  ) async {
    await openWizard(tester);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Selecciona el tipo de documento.'), findsOneWidget);
  });

  testWidgets('limita el numero de documento al tope del tipo (CC=10)', (
    tester,
  ) async {
    await openWizard(tester);

    // Selecciona CC (primer dropdown) para fijar la regla.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC - Cedula de Ciudadania').last);
    await tester.pumpAndSettle();

    final documentField = find.byType(TextFormField).at(0);
    await tester.enterText(documentField, '9' * 30);
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: documentField, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text.length, documentRuleFor('CC')!.maxLength);
  });

  testWidgets('rechaza documento invalido para CC antes de buscar duplicado', (
    tester,
  ) async {
    await openWizard(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC - Cedula de Ciudadania').last);
    await tester.pumpAndSettle();

    // CC con letras -> invalido por la regla numerica.
    final documentField = find.byType(TextFormField).at(0);
    await tester.enterText(documentField, '12345');
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(2), 'Diaz');
    await tester.pump();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Documento invalido'), findsOneWidget);
    expect(find.text('Paciente ya registrado'), findsNothing);
  });

  testWidgets('limpia el numero al cambiar de tipo de documento', (
    tester,
  ) async {
    await openWizard(tester);

    // TI permite 11; se llena con 11 caracteres.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TI - Tarjeta de Identidad').last);
    await tester.pumpAndSettle();

    final documentField = find.byType(TextFormField).at(0);
    await tester.enterText(documentField, '12345678901');
    await tester.pump();
    expect(textOf(tester, documentField), '12345678901');

    // Cambiar a CC (max 10) debe limpiar el valor previo.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC - Cedula de Ciudadania').last);
    await tester.pumpAndSettle();

    expect(textOf(tester, documentField), isEmpty);
  });
}

String textOf(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

class _FakePatientsRepository extends _UnusedPatientsRepository {
  _FakePatientsRepository(this.patients);

  final List<Patient> patients;

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  }) async => patients;
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
