import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../domain/entities/catalog_entities.dart';
import '../domain/entities/effective_catalog.dart';
import '../domain/entities/geo.dart';
import '../domain/repositories/catalog_repository.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this.api, this.database);
  final ApiClient api;
  final AppDatabase database;

  static const _effectiveCatalogKey = 'effective_catalog_v1';
  static const _departmentsKey = 'geo_departments_v1';
  static const _countriesKey = 'geo_countries_v1';
  static const _referenceCatalogsKey = 'reference_catalogs_v1';
  static const _insurersKey = 'insurers_v1';
  static String _municipalitiesKey(String departmentId) =>
      'geo_municipalities_v1_$departmentId';

  /// Lee del cache JSON en [SyncMetadata] como respaldo offline.
  Future<List<Map<String, dynamic>>?> _cachedJsonList(String key) async {
    final raw = await database.syncMetadataValue(key);
    if (raw == null || raw.isEmpty) return null;
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _cacheJsonList(String key, List<Map<String, dynamic>> value) =>
      database.setSyncMetadata(key, jsonEncode(value));

  @override
  Future<List<EffectiveVaccine>> listEffectiveCatalog(String token) async {
    try {
      final raw = await api.getEffectiveCatalog(token);
      await _cacheJsonList(_effectiveCatalogKey, raw);
      return raw.map(EffectiveVaccine.fromJson).toList();
    } on ApiException {
      final cached = await _cachedJsonList(_effectiveCatalogKey);
      if (cached == null || cached.isEmpty) rethrow;
      return cached.map(EffectiveVaccine.fromJson).toList();
    }
  }

  @override
  Future<List<GeoCountry>> listCountries(String token) async {
    try {
      final raw = await api.getCountries(token);
      await _cacheJsonList(_countriesKey, raw);
      return raw.map(GeoCountry.fromJson).toList();
    } on ApiException {
      final cached = await _cachedJsonList(_countriesKey);
      if (cached == null || cached.isEmpty) rethrow;
      return cached.map(GeoCountry.fromJson).toList();
    }
  }

  @override
  Future<List<ReferenceCatalog>> listReferenceCatalogs(String token) async {
    try {
      final raw = await api.getReferenceCatalogs(token);
      await _cacheJsonList(_referenceCatalogsKey, raw);
      return raw.map(ReferenceCatalog.fromJson).toList();
    } on ApiException {
      final cached = await _cachedJsonList(_referenceCatalogsKey);
      if (cached == null || cached.isEmpty) rethrow;
      return cached.map(ReferenceCatalog.fromJson).toList();
    }
  }

  @override
  Future<List<HealthInsurer>> listInsurers(String token) async {
    try {
      final raw = await api.getInsurers(token);
      await _cacheJsonList(_insurersKey, raw);
      return raw.map(HealthInsurer.fromJson).toList();
    } on ApiException {
      final cached = await _cachedJsonList(_insurersKey);
      if (cached == null || cached.isEmpty) rethrow;
      return cached.map(HealthInsurer.fromJson).toList();
    }
  }

  @override
  Future<List<GeoDepartment>> listDepartments(String token) async {
    try {
      final raw = await api.getDepartments(token);
      await _cacheJsonList(_departmentsKey, raw);
      return raw.map(GeoDepartment.fromJson).toList();
    } on ApiException {
      final cached = await _cachedJsonList(_departmentsKey);
      if (cached == null || cached.isEmpty) rethrow;
      return cached.map(GeoDepartment.fromJson).toList();
    }
  }

  @override
  Future<List<GeoMunicipality>> listMunicipalities(
    String token,
    String departmentId,
  ) async {
    final key = _municipalitiesKey(departmentId);
    try {
      final raw = await api.getMunicipalities(token, departmentId);
      await _cacheJsonList(key, raw);
      return raw.map(GeoMunicipality.fromJson).toList();
    } on ApiException {
      final cached = await _cachedJsonList(key);
      if (cached == null || cached.isEmpty) rethrow;
      return cached.map(GeoMunicipality.fromJson).toList();
    }
  }

  @override
  Future<List<Vaccine>> listVaccines(String token) async {
    try {
      final result = (await api.listCatalogVaccines(token))
          .map(Vaccine.fromJson)
          .toList();
      await database.replaceVaccineCache(result);
      return result;
    } on ApiException {
      final cached = await database.cachedVaccines();
      if (cached.isEmpty) rethrow;
      return cached
          .map(
            (v) => Vaccine(
              id: v.id,
              name: v.name,
              code: v.code,
              category: v.category,
              maxDoses: v.maxDoses,
              minAgeMonths: v.minAgeMonths,
              maxAgeMonths: v.maxAgeMonths,
              active: v.active,
              version: v.version,
            ),
          )
          .toList();
    }
  }

  @override
  Future<List<InstitutionVaccine>> listInstitutionVaccines(
    String token,
    String institutionId,
  ) async {
    try {
      final result = (await api.listInstitutionCatalogVaccines(
        token,
        institutionId,
      )).map(InstitutionVaccine.fromJson).toList();
      await database.replaceInstitutionVaccines(institutionId, result);
      return result;
    } on ApiException {
      final cached = await database.cachedInstitutionVaccines(institutionId);
      if (cached.isEmpty) rethrow;
      return cached
          .map(
            (v) => InstitutionVaccine(
              id: v.id,
              institutionId: v.institutionId,
              vaccineId: v.vaccineId,
              name: v.name,
              code: v.code,
              category: v.category,
              enabled: v.enabled,
              version: v.version,
            ),
          )
          .toList();
    }
  }

  @override
  Future<List<Vaccine>> listAvailableInstitutionVaccines(
    String token,
    String institutionId,
  ) async {
    final result = (await api.listAvailableInstitutionVaccines(
      token,
      institutionId,
    )).map(Vaccine.fromJson).toList();
    return result;
  }

  @override
  Future<Vaccine> createVaccine(
    String token,
    Map<String, dynamic> body,
  ) async => Vaccine.fromJson(await api.createCatalogVaccine(token, body));
  @override
  Future<Vaccine> updateVaccine(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body,
  ) async => Vaccine.fromJson(
    await api.updateCatalogVaccine(token, vaccine.id, vaccine.version, body),
  );
  @override
  Future<void> deleteVaccine(String token, Vaccine vaccine) =>
      api.deleteCatalogVaccine(token, vaccine.id, vaccine.version);
  @override
  Future<List<VaccineOption>> listOptions(
    String token,
    Vaccine vaccine, {
    required bool institutionScoped,
    required String institutionId,
  }) async {
    try {
      final result = (await api.listCatalogOptions(
        token,
        vaccine.id,
        institutionId: institutionScoped ? institutionId : null,
      )).map(VaccineOption.fromJson).toList();
      if (institutionScoped) {
        await database.replaceInstitutionOptions(
          institutionId,
          vaccine.id,
          result,
        );
      } else {
        await database.replaceGlobalOptions(vaccine.id, result);
      }
      return result;
    } on ApiException {
      if (institutionScoped) {
        final cached = await database.cachedInstitutionOptions(
          institutionId,
          vaccine.id,
        );
        if (cached.isEmpty) rethrow;
        return cached
            .map(
              (o) => VaccineOption(
                id: o.id,
                vaccineId: o.vaccineId,
                institutionId: o.institutionId,
                fieldType: o.fieldType,
                value: o.value,
                displayName: o.displayName,
                sortOrder: o.sortOrder,
                isDefault: o.isDefault,
                isActive: o.isActive,
                sourceTemplateId: o.sourceTemplateId,
                version: o.version,
              ),
            )
            .toList();
      }
      final cached = await database.cachedGlobalOptions(vaccine.id);
      if (cached.isEmpty) rethrow;
      return cached
          .map(
            (o) => VaccineOption(
              id: o.id,
              vaccineId: o.vaccineId,
              fieldType: o.fieldType,
              value: o.value,
              displayName: o.displayName,
              sortOrder: o.sortOrder,
              isDefault: o.isDefault,
              isActive: o.isActive,
              sourceTemplateId: o.sourceTemplateId,
              version: o.version,
            ),
          )
          .toList();
    }
  }

  @override
  Future<VaccineOption> createOption(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required bool institutionScoped,
    required String institutionId,
  }) async => VaccineOption.fromJson(
    await api.createCatalogOption(
      token,
      vaccine.id,
      body,
      institutionId: institutionScoped ? institutionId : null,
    ),
  );
  @override
  Future<VaccineOption> updateOption(
    String token,
    Vaccine vaccine,
    VaccineOption option,
    Map<String, dynamic> body, {
    required bool institutionScoped,
    required String institutionId,
  }) async => VaccineOption.fromJson(
    await api.updateCatalogOption(
      token,
      vaccine.id,
      option.id,
      body,
      institutionId: institutionScoped ? institutionId : null,
    ),
  );
  @override
  Future<void> deleteOption(
    String token,
    Vaccine vaccine,
    VaccineOption option, {
    required bool institutionScoped,
    required String institutionId,
  }) => api.deleteCatalogOption(
    token,
    vaccine.id,
    option.id,
    option.version,
    institutionId: institutionScoped ? institutionId : null,
  );

  @override
  Future<void> disableOption(
    String token,
    Vaccine vaccine,
    VaccineOption option, {
    required bool institutionScoped,
    required String institutionId,
  }) async {
    final body = optionPayload(
      fieldType: option.fieldType,
      value: option.value,
      isDefault: false,
      sortOrder: option.sortOrder,
      version: option.version,
    )..['isActive'] = false;
    await updateOption(
      token,
      vaccine,
      option,
      body,
      institutionScoped: institutionScoped,
      institutionId: institutionId,
    );
  }

  @override
  Future<void> setEnabled(
    String token,
    Vaccine vaccine, {
    required String institutionId,
    required bool enabled,
  }) => api.setInstitutionVaccineEnabled(
    token,
    institutionId,
    vaccine.id,
    enabled,
  );
  @override
  Future<List<VaccineOption>> suggestedOptions(
    String token,
    Vaccine vaccine,
    String institutionId,
  ) async => (await api.suggestedCatalogOptions(
    token,
    institutionId,
    vaccine.id,
  )).map(VaccineOption.fromJson).toList();
  @override
  Future<List<VaccineOption>> importSuggestedOptions(
    String token,
    Vaccine vaccine,
    String institutionId,
  ) async => (await api.importSuggestedCatalogOptions(
    token,
    institutionId,
    vaccine.id,
  )).map(VaccineOption.fromJson).toList();

  @override
  Future<List<VaccineOption>> listTemplates(
    String token,
    Vaccine vaccine,
  ) async => (await api.listCatalogTemplates(
    token,
    vaccine.id,
  )).map(VaccineOption.fromJson).toList();

  @override
  Future<VaccineOption> createTemplate(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body,
  ) async => VaccineOption.fromJson(
    await api.createCatalogTemplate(token, vaccine.id, body),
  );
}
