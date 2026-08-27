import 'package:flutter/foundation.dart';

import '../../../core/auth/offline_access.dart';
import '../../../core/auth/offline_policy.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_exception.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/entities/catalog_entities.dart';
import '../domain/use_cases/catalog_use_cases.dart';

class CatalogController extends ChangeNotifier {
  CatalogController({
    required this.sessionManager,
    required this.repository,
    required this.listVaccines,
    required this.saveVaccine,
    required this.toggle,
  }) : _vaccines = [];
  final SessionManager sessionManager;
  final CatalogRepository repository;
  final ListVaccines listVaccines;
  final SaveVaccine saveVaccine;
  final ToggleInstitutionVaccine toggle;
  List<Vaccine> _vaccines;
  final Map<String, bool> institutionEnabled = {};
  bool isLoading = false;
  String? error;
  String query = '';
  String? selectedCategory;
  List<Vaccine> get vaccines => List.unmodifiable(_vaccines);
  List<Vaccine> get filteredVaccines => _vaccines
      .where(
        (v) =>
            (query.isEmpty ||
                '${v.name} ${v.code}'.toLowerCase().contains(
                  query.toLowerCase(),
                )) &&
            (selectedCategory == null || v.category == selectedCategory),
      )
      .toList();
  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> load() async {
    final token = await _token();
    if (token == null) {
      error = 'Tu sesion expiro. Inicia sesion de nuevo.';
      notifyListeners();
      return;
    }
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      _vaccines = await listVaccines(token);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo cargar el catalogo.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInstitution(String institutionId) async {
    final token = await _token();
    if (token == null) {
      error = 'Tu sesion expiro. Inicia sesion de nuevo.';
      notifyListeners();
      return;
    }
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final relations = await repository.listInstitutionVaccines(
        token,
        institutionId,
      );
      institutionEnabled
        ..clear()
        ..addEntries(
          relations.map(
            (relation) => MapEntry(relation.vaccineId, relation.enabled),
          ),
        );
      _vaccines = relations
          .map(
            (relation) => Vaccine(
              id: relation.vaccineId,
              name: relation.name,
              code: relation.code,
              category: relation.category,
              maxDoses: 1,
              active: true,
              version: relation.version,
            ),
          )
          .toList();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo cargar el catalogo institucional.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(
    Map<String, dynamic> body, {
    Vaccine? existing,
    required OfflineAccess offline,
  }) async {
    try {
      const OfflinePolicy().ensureWritable(
        status: offline.status,
        permissions: offline.permissions,
        operation: OperationPermission.catalogGlobalWrite,
      );
    } on OfflinePolicyException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
    final token = await _token();
    if (token == null) {
      error = 'Tu sesion expiro. Inicia sesion de nuevo.';
      notifyListeners();
      return false;
    }
    try {
      final saved = await saveVaccine(token, body, existing: existing);
      _vaccines = [..._vaccines.where((v) => v.id != saved.id), saved]
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.statusCode == 409
          ? 'El codigo ya existe o el registro cambio. Recarga e intenta de nuevo.'
          : e.message;
      notifyListeners();
      return false;
    } catch (_) {
      error = 'No se pudo guardar la vacuna.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setEnabled(
    Vaccine vaccine,
    String institutionId,
    bool enabled,
    OfflineAccess offline,
  ) async {
    try {
      const OfflinePolicy().ensureWritable(
        status: offline.status,
        permissions: offline.permissions,
        operation: OperationPermission.catalogConfigWrite,
      );
    } on OfflinePolicyException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
    final token = await _token();
    if (token == null) return false;
    try {
      await toggle(token, vaccine, institutionId, enabled);
      institutionEnabled[vaccine.id] = enabled;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.statusCode == 409
          ? 'El catalogo cambio en otro dispositivo. Recarga antes de continuar.'
          : e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addOption(
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required String institutionId,
    required bool institutionScoped,
    required OfflineAccess offline,
  }) async {
    try {
      const OfflinePolicy().ensureWritable(
        status: offline.status,
        permissions: offline.permissions,
        operation: institutionScoped
            ? OperationPermission.catalogConfigWrite
            : OperationPermission.catalogGlobalWrite,
      );
      final token = await _token();
      if (token == null) return false;
      await repository.createOption(
        token,
        vaccine,
        body,
        institutionScoped: institutionScoped,
        institutionId: institutionId,
      );
      return true;
    } on OfflinePolicyException catch (e) {
      error = e.message;
    } on ApiException catch (e) {
      error = e.statusCode == 409
          ? 'La opcion cambio en otro dispositivo. Recarga e intenta de nuevo.'
          : e.message;
    }
    notifyListeners();
    return false;
  }

  Future<bool> updateOption(
    Vaccine vaccine,
    VaccineOption option,
    Map<String, dynamic> body, {
    required String institutionId,
    required bool institutionScoped,
    required OfflineAccess offline,
  }) async {
    try {
      const OfflinePolicy().ensureWritable(
        status: offline.status,
        permissions: offline.permissions,
        operation: institutionScoped
            ? OperationPermission.catalogConfigWrite
            : OperationPermission.catalogGlobalWrite,
      );
      final token = await _token();
      if (token == null) return false;
      await repository.updateOption(
        token,
        vaccine,
        option,
        body,
        institutionScoped: institutionScoped,
        institutionId: institutionId,
      );
      return true;
    } on OfflinePolicyException catch (e) {
      error = e.message;
    } on ApiException catch (e) {
      error = e.statusCode == 409
          ? 'La opcion fue modificada por otro usuario. Recarga e intenta de nuevo.'
          : e.message;
    }
    notifyListeners();
    return false;
  }

  Future<bool> addTemplate(
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required OfflineAccess offline,
  }) async {
    try {
      const OfflinePolicy().ensureWritable(
        status: offline.status,
        permissions: offline.permissions,
        operation: OperationPermission.catalogGlobalWrite,
      );
      final token = await _token();
      if (token == null) return false;
      await repository.createTemplate(token, vaccine, body);
      return true;
    } on OfflinePolicyException catch (e) {
      error = e.message;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
    return false;
  }

  Future<bool> disableOption(
    Vaccine vaccine,
    VaccineOption option, {
    required String institutionId,
    required bool institutionScoped,
    required OfflineAccess offline,
  }) async => updateOption(
    vaccine,
    option,
    optionPayload(
      fieldType: option.fieldType,
      value: option.value,
      isDefault: false,
      sortOrder: option.sortOrder,
      version: option.version,
    )..['isActive'] = false,
    institutionId: institutionId,
    institutionScoped: institutionScoped,
    offline: offline,
  );

  Future<String?> _token() async =>
      (await sessionManager.loadSession())?.accessToken;
}
