import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/shimmer_loading.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/entities/attention.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/geo.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient_profile.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/patient_profile_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/pages/patient_detail_page.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/patient_detail_controller.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['PATIENT_WRITE', 'PATIENT_READ'],
  );

  testWidgets('muestra Shimmer Skeleton mientras carga y resuelve Colombia por defecto', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final completer = Completer<PatientProfile>();
    final repository = _AsyncPatientsRepository(completer);

    final controller = PatientDetailController(
      sessionManager: FakeSessionManager('token-123'),
      getPatient: GetPatient(repository),
      updateDemographics: UpdatePatientDemographics(repository),
      updateContact: UpdatePatientContact(repository),
      updateMedicalHistories: UpdatePatientMedicalHistories(repository),
      listCountries: ListCountries(_StubCatalogRepository()),
      listDepartments: ListDepartments(_StubCatalogRepository()),
      listMunicipalities: ListMunicipalities(_StubCatalogRepository()),
      listPatientAttentions: ListPatientAttentions(_StubAttentionsRepository()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PatientDetailPage(
          controller: controller,
          offline: online,
          patientId: 'p1',
        ),
      ),
    );

    // 1. Estado de carga inicial: debe mostrar el skeleton con Shimmer
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ShimmerLoading), findsOneWidget);
    expect(find.byKey(const ValueKey('patient_skeleton')), findsOneWidget);

    // 2. Simulamos la respuesta de la API con paciente sin país explícito
    completer.complete(
      PatientProfile(
        patient: Patient(
          id: 'p1',
          documentType: 'CC',
          documentNumber: '1098765432',
          firstName: 'Carlos',
          lastName: 'Mendoza',
          birthDate: DateTime(1995, 5, 20),
          sex: 'MALE',
          status: 'ACTIVE',
          birthCountryId: null, // Sin país explícito
        ),
        addresses: const [
          PatientAddress(
            id: 'addr-1',
            street: 'Calle 10 # 5-20',
            countryId: null, // Sin país explícito
          ),
        ],
      ),
    );

    // 3. Transición AnimatedSwitcher (300ms)
    await tester.pump(const Duration(milliseconds: 400));

    // Debe mostrar la vista con datos del paciente
    expect(find.byKey(const ValueKey('patient_content')), findsOneWidget);
    expect(find.text('Carlos Mendoza'), findsWidgets);

    // País de nacimiento y de residencia deben resolver automáticamente a "Colombia"
    expect(find.text('Colombia'), findsWidgets);
  });
}

class _AsyncPatientsRepository implements PatientsRepository {
  _AsyncPatientsRepository(this.completer);
  final Completer<PatientProfile> completer;

  @override
  Future<PatientProfile> getById(String accessToken, String patientId) =>
      completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubCatalogRepository implements CatalogRepository {
  @override
  Future<List<GeoCountry>> listCountries(String accessToken) async => [
        const GeoCountry(id: 'col-id', code: '170', name: 'Colombia'),
      ];

  @override
  Future<List<GeoDepartment>> listDepartments(String accessToken) async => [];

  @override
  Future<List<GeoMunicipality>> listMunicipalities(
    String accessToken,
    String departmentId,
  ) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAttentionsRepository implements AttentionsRepository {
  @override
  Future<List<Attention>> listByPatient(
    String accessToken,
    String patientId,
  ) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
