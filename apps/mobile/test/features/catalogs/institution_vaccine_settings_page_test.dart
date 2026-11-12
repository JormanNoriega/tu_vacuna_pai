import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/catalog_entities.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/catalogs/presentation/catalog_controller.dart';
import 'package:tu_vacuna_pai/features/catalogs/presentation/pages/institution_vaccine_settings_page.dart';

class _Session extends SessionManager {
  _Session() : super(const FlutterSecureStorage());
  @override
  Future<SessionData?> loadSession() async => SessionData(
    accessToken: 'token',
    refreshToken: '',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    lastOnlineValidation: DateTime.now(),
  );
}

class _Repository implements CatalogRepository {
  @override
  Future<List<VaccineOption>> listOptions(
    String token,
    Vaccine vaccine, {
    required bool institutionScoped,
    required String institutionId,
  }) async => [];
  @override
  Future<List<EffectiveVaccine>> listEffectiveCatalog(String token) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('el interruptor y el cierre del diálogo no generan excepciones', (
    tester,
  ) async {
    final repo = _Repository();
    final controller = CatalogController(
      sessionManager: _Session(),
      repository: repo,
      listVaccines: ListVaccines(repo),
      saveVaccine: SaveVaccine(repo),
      toggle: ToggleInstitutionVaccine(repo),
      listAvailableVaccines: ListAvailableInstitutionVaccines(repo),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InstitutionVaccineSettingsPage(
          controller: controller,
          vaccine: const Vaccine(
            id: 'v',
            name: 'Vacuna',
            code: 'V',
            category: 'PAI',
            maxDoses: 1,
            active: true,
            version: 1,
            hasSyringe: true,
          ),
          institutionId: 'i',
          offline: const OfflineAccess(
            status: SessionStatus.signedIn,
            permissions: [],
          ),
          canWrite: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byTooltip('Agregar Jeringas disponibles'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Agregar Jeringas disponibles'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Prueba');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
