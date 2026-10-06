import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/features/catalogs/application/catalog_warmup.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/catalog_entities.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/geo.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';

void main() {
  test(
    'run precarga referencia, EPS, paises, geo y catalogo efectivo',
    () async {
      final repository = _FakeCatalogRepository();
      final warmup = CatalogWarmup(
        sessionManager: _FakeSessionManager('token'),
        repository: repository,
      );

      await warmup.run();

      expect(repository.calls, [
        'reference',
        'insurers',
        'countries',
        'fullGeo',
        'effective',
      ]);
    },
  );

  test('run no hace nada sin sesion', () async {
    final repository = _FakeCatalogRepository();
    final warmup = CatalogWarmup(
      sessionManager: _FakeSessionManager(null),
      repository: repository,
    );

    await warmup.run();

    expect(repository.calls, isEmpty);
  });

  test('run continua aunque una precarga falle', () async {
    final repository = _FakeCatalogRepository()..failFullGeo = true;
    final warmup = CatalogWarmup(
      sessionManager: _FakeSessionManager('token'),
      repository: repository,
    );

    await warmup.run();

    expect(repository.calls, [
      'reference',
      'insurers',
      'countries',
      'fullGeo',
      'effective',
    ]);
  });
}

class _FakeSessionManager extends SessionManager {
  _FakeSessionManager(this._token) : super(const FlutterSecureStorage());

  final String? _token;

  @override
  Future<SessionData?> loadSession() async {
    final token = _token;
    if (token == null) return null;
    return SessionData(
      accessToken: token,
      refreshToken: '',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      lastOnlineValidation: DateTime.now(),
    );
  }
}

class _FakeCatalogRepository implements CatalogRepository {
  final List<String> calls = [];
  bool failFullGeo = false;

  @override
  Future<List<ReferenceCatalog>> listReferenceCatalogs(String token) async {
    calls.add('reference');
    return const [];
  }

  @override
  Future<List<HealthInsurer>> listInsurers(String token) async {
    calls.add('insurers');
    return const [];
  }

  @override
  Future<List<GeoCountry>> listCountries(String token) async {
    calls.add('countries');
    return const [];
  }

  @override
  Future<List<GeoDepartment>> listFullGeo(String token) async {
    calls.add('fullGeo');
    if (failFullGeo) throw Exception('sin red');
    return const [];
  }

  @override
  Future<List<EffectiveVaccine>> listEffectiveCatalog(String token) async {
    calls.add('effective');
    return const [];
  }

  @override
  Future<List<Vaccine>> listVaccines(String token) => _unimplemented();

  @override
  Future<List<GeoDepartment>> listDepartments(String token) => _unimplemented();

  @override
  Future<List<GeoMunicipality>> listMunicipalities(
    String token,
    String departmentId,
  ) => _unimplemented();

  @override
  Future<List<InstitutionVaccine>> listInstitutionVaccines(
    String token,
    String institutionId,
  ) => _unimplemented();

  @override
  Future<List<Vaccine>> listAvailableInstitutionVaccines(
    String token,
    String institutionId,
  ) => _unimplemented();

  @override
  Future<Vaccine> createVaccine(String token, Map<String, dynamic> body) =>
      _unimplemented();

  @override
  Future<Vaccine> updateVaccine(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body,
  ) => _unimplemented();

  @override
  Future<void> deleteVaccine(String token, Vaccine vaccine) => _unimplemented();

  @override
  Future<List<VaccineOption>> listOptions(
    String token,
    Vaccine vaccine, {
    required bool institutionScoped,
    required String institutionId,
  }) => _unimplemented();

  @override
  Future<VaccineOption> createOption(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required bool institutionScoped,
    required String institutionId,
  }) => _unimplemented();

  @override
  Future<VaccineOption> updateOption(
    String token,
    Vaccine vaccine,
    VaccineOption option,
    Map<String, dynamic> body, {
    required bool institutionScoped,
    required String institutionId,
  }) => _unimplemented();

  @override
  Future<void> deleteOption(
    String token,
    Vaccine vaccine,
    VaccineOption option, {
    required bool institutionScoped,
    required String institutionId,
  }) => _unimplemented();

  @override
  Future<void> disableOption(
    String token,
    Vaccine vaccine,
    VaccineOption option, {
    required bool institutionScoped,
    required String institutionId,
  }) => _unimplemented();

  @override
  Future<void> setEnabled(
    String token,
    Vaccine vaccine, {
    required String institutionId,
    required bool enabled,
  }) => _unimplemented();

  @override
  Future<List<VaccineOption>> suggestedOptions(
    String token,
    Vaccine vaccine,
    String institutionId,
  ) => _unimplemented();

  @override
  Future<List<VaccineOption>> listTemplates(String token, Vaccine vaccine) =>
      _unimplemented();

  @override
  Future<VaccineOption> createTemplate(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body,
  ) => _unimplemented();

  @override
  Future<List<VaccineOption>> importSuggestedOptions(
    String token,
    Vaccine vaccine,
    String institutionId,
  ) => _unimplemented();

  Future<T> _unimplemented<T>() => throw UnimplementedError();
}
