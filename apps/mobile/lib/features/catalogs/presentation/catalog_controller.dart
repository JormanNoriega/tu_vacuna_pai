import '../../../core/auth/offline_access.dart';
import '../../../core/auth/offline_policy.dart';
import '../../../core/presentation/async_controller.dart';
import '../../../core/network/api_exception.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/entities/catalog_entities.dart';
import '../domain/use_cases/catalog_use_cases.dart';

class CatalogController extends AsyncController {
  CatalogController({
    required super.sessionManager,
    required this.repository,
    required this.listVaccines,
    required this.saveVaccine,
    required this.toggle,
    required this.listAvailableVaccines,
  });

  final CatalogRepository repository;
  final ListVaccines listVaccines;
  final SaveVaccine saveVaccine;
  final ToggleInstitutionVaccine toggle;
  final ListAvailableInstitutionVaccines listAvailableVaccines;
  List<Vaccine> _vaccines = const [];
  List<Vaccine> _availableVaccines = const [];

  final Map<String, bool> institutionEnabled = {};
  final Map<String, List<VaccineOption>> doseOptions = {};
  String query = '';
  String? selectedCategory;

  List<Vaccine> get vaccines => List.unmodifiable(_vaccines);
  List<Vaccine> get availableVaccines => List.unmodifiable(_availableVaccines);
  bool get hasAvailableVaccines => _availableVaccines.isNotEmpty;
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

  Future<void> load() => execute((token) async {
    _vaccines = await listVaccines(token);
    await _loadDoseOptions(token, _vaccines);
  });

  Future<void> loadInstitution(String institutionId) => execute((token) async {
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
    await _loadDoseOptions(token, _vaccines);
  });

  /// Carga las vacunas globales activas que la institucion aun no tiene
  /// relacionadas (disponibles para habilitar).
  Future<void> loadAvailable(String institutionId) async {
    _availableVaccines = await listAvailableVaccines(
      await _requireToken(),
      institutionId,
    );
    notifyListeners();
  }

  /// Habilita una vacuna disponible en la institucion. Reutiliza el toggle
  /// existente (enable es copy-once: copia los templates actuales solo si la
  /// relacion es nueva, sin tocar configuraciones existentes).
  Future<bool> enableAvailable(Vaccine vaccine, String institutionId) async {
    var success = false;
    await execute((token) async {
      await toggle(token, vaccine, institutionId, true);
      _availableVaccines = _availableVaccines
          .where((v) => v.id != vaccine.id)
          .toList();
      success = true;
    });
    return success;
  }

  Future<String> _requireToken() async {
    final session = await sessionManager.loadSession();
    return session?.accessToken ?? '';
  }

  Future<bool> save(
    Map<String, dynamic> body, {
    Vaccine? existing,
    required OfflineAccess offline,
  }) async {
    if (!_ensureWritable(offline, OperationPermission.catalogGlobalWrite)) {
      return false;
    }
    var success = false;
    await execute((token) async {
      final saved = await saveVaccine(token, body, existing: existing);
      _vaccines = [..._vaccines.where((v) => v.id != saved.id), saved]
        ..sort((a, b) => a.name.compareTo(b.name));
      success = true;
    });
    return success;
  }

  Future<bool> setEnabled(
    Vaccine vaccine,
    String institutionId,
    bool enabled,
    OfflineAccess offline,
  ) async {
    if (!_ensureWritable(offline, OperationPermission.catalogConfigWrite)) {
      return false;
    }
    var success = false;
    await execute((token) async {
      await toggle(token, vaccine, institutionId, enabled);
      institutionEnabled[vaccine.id] = enabled;
      success = true;
    });
    return success;
  }

  Future<bool> addOption(
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required String institutionId,
    required bool institutionScoped,
    required OfflineAccess offline,
  }) async {
    if (!_ensureWritable(
      offline,
      institutionScoped
          ? OperationPermission.catalogConfigWrite
          : OperationPermission.catalogGlobalWrite,
    )) {
      return false;
    }
    var success = false;
    await execute((token) async {
      await repository.createOption(
        token,
        vaccine,
        body,
        institutionScoped: institutionScoped,
        institutionId: institutionId,
      );
      success = true;
    });
    return success;
  }

  Future<bool> updateOption(
    Vaccine vaccine,
    VaccineOption option,
    Map<String, dynamic> body, {
    required String institutionId,
    required bool institutionScoped,
    required OfflineAccess offline,
  }) async {
    if (!_ensureWritable(
      offline,
      institutionScoped
          ? OperationPermission.catalogConfigWrite
          : OperationPermission.catalogGlobalWrite,
    )) {
      return false;
    }
    var success = false;
    await execute((token) async {
      await repository.updateOption(
        token,
        vaccine,
        option,
        body,
        institutionScoped: institutionScoped,
        institutionId: institutionId,
      );
      success = true;
    });
    return success;
  }

  Future<bool> addTemplate(
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required OfflineAccess offline,
  }) async {
    if (!_ensureWritable(offline, OperationPermission.catalogGlobalWrite)) {
      return false;
    }
    var success = false;
    await execute((token) async {
      await repository.createTemplate(token, vaccine, body);
      success = true;
    });
    return success;
  }

  /// Desactiva una opcion. La construccion del payload (DTO) la resuelve el
  /// repositorio; el controller no conoce el wire protocol.
  Future<bool> disableOption(
    Vaccine vaccine,
    VaccineOption option, {
    required String institutionId,
    required bool institutionScoped,
    required OfflineAccess offline,
  }) async {
    if (!_ensureWritable(
      offline,
      institutionScoped
          ? OperationPermission.catalogConfigWrite
          : OperationPermission.catalogGlobalWrite,
    )) {
      return false;
    }
    var success = false;
    await execute((token) async {
      await repository.disableOption(
        token,
        vaccine,
        option,
        institutionScoped: institutionScoped,
        institutionId: institutionId,
      );
      success = true;
    });
    return success;
  }

  bool _ensureWritable(OfflineAccess offline, OperationPermission operation) {
    try {
      const OfflinePolicy().ensureWritable(
        status: offline.status,
        permissions: offline.permissions,
        operation: operation,
      );
      return true;
    } on OfflinePolicyException catch (e) {
      setError(e.message);
      return false;
    }
  }

  @override
  String mapApiError(ApiException e) => e.statusCode == 409
      ? 'El catalogo cambio en otro dispositivo. Recarga e intenta de nuevo.'
      : e.message;

  Future<void> _loadDoseOptions(String token, List<Vaccine> vaccines) async {
    final results = await Future.wait(
      vaccines.map((vaccine) async {
        try {
          final options = await repository.listOptions(
            token,
            vaccine,
            institutionScoped: false,
            institutionId: '',
          );
          return MapEntry(
            vaccine.id,
            options.where((option) => option.fieldType == 'dose').toList(),
          );
        } catch (_) {
          return MapEntry(vaccine.id, <VaccineOption>[]);
        }
      }),
    );
    doseOptions
      ..clear()
      ..addEntries(results);
  }
}
