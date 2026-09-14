import '../../../core/auth/offline_access.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/async_controller.dart';
import '../../../core/synchronization/clinical_offline_repository.dart';
import '../../../core/utils/uuid.dart';
import '../../auth/domain/entities/session_restore_result.dart';
import '../../catalogs/domain/entities/catalog_entities.dart';
import '../../catalogs/domain/entities/effective_catalog.dart';
import '../../catalogs/domain/entities/geo.dart';
import '../../catalogs/domain/use_cases/catalog_use_cases.dart';
import '../../patients/domain/entities/new_patient.dart';
import '../../patients/domain/entities/patient.dart';
import '../../patients/domain/use_cases/create_patient.dart';
import '../../patients/domain/use_cases/search_patient.dart';
import '../domain/entities/attention.dart';
import '../domain/use_cases/attentions_use_cases.dart';

/// Orquesta el flujo clinico del vacunador: busqueda/creacion de paciente,
/// seleccion de vacuna del catalogo efectivo, registro de dosis y cierre de la
/// atencion.
///
/// Camino offline: cuando la sesion esta en [SessionStatus.offlineAuthorized],
/// la cadena clinica escribe en el working set local + outbox a traves de
/// [offlineRepository]; el [SyncEngine] la empuja al reconectar. Con sesion
/// online se mantiene el camino online-first contra la API. Las cancelaciones y
/// ediciones siguen siendo online-only.
class AttentionController extends AsyncController {
  AttentionController({
    required super.sessionManager,
    required this.searchPatient,
    required this.createPatient,
    required this.listEffectiveCatalog,
    required this.listCountries,
    required this.listDepartments,
    required this.listMunicipalities,
    required this.listReferenceCatalogs,
    required this.listInsurers,
    required this.createAttention,
    required this.updateAttention,
    required this.registerDose,
    required this.completeAttention,
    required this.cancelAttention,
    required this.cancelDose,
    this.offlineRepository,
  });

  final SearchPatient searchPatient;
  final CreatePatient createPatient;
  final ListEffectiveCatalog listEffectiveCatalog;
  final ListCountries listCountries;
  final ListDepartments listDepartments;
  final ListMunicipalities listMunicipalities;
  final ListReferenceCatalogs listReferenceCatalogs;
  final ListInsurers listInsurers;
  final CreateAttention createAttention;
  final UpdateAttention updateAttention;
  final RegisterDose registerDose;
  final CompleteAttention completeAttention;
  final CancelAttention cancelAttention;
  final CancelDose cancelDose;

  /// Repositorio local-first de la cadena clinica. Null en tests/demos, donde
  /// el flujo opera solo online.
  final ClinicalOfflineRepository? offlineRepository;

  bool _isOffline(OfflineAccess offline) =>
      offlineRepository != null &&
      offline.status == SessionStatus.offlineAuthorized;

  List<EffectiveVaccine> _effectiveVaccines = const [];
  List<Patient> _searchResults = const [];
  List<GeoCountry> _countries = const [];
  List<GeoDepartment> _departments = const [];
  List<GeoMunicipality> _municipalities = const [];
  Map<String, List<ReferenceOption>> _referenceCatalogs = const {};
  List<HealthInsurer> _insurers = const [];
  Patient? _patient;
  Attention? _attention;
  bool _effectiveCatalogLoaded = false;

  List<EffectiveVaccine> get effectiveVaccines =>
      List.unmodifiable(_effectiveVaccines);
  List<Patient> get searchResults => List.unmodifiable(_searchResults);
  List<GeoCountry> get countries => List.unmodifiable(_countries);
  List<GeoDepartment> get departments => List.unmodifiable(_departments);
  List<GeoMunicipality> get municipalities =>
      List.unmodifiable(_municipalities);

  /// Opciones de un catalogo de referencia por codigo (`document_type`,
  /// `sex`, `gender`, `affiliation_regime`, `insurer`, ...).
  List<ReferenceOption> referenceOptions(String code) =>
      _referenceCatalogs[code] ?? const [];

  /// Aseguradoras (EPS) activas del catalogo global.
  List<HealthInsurer> get insurers => List.unmodifiable(_insurers);

  /// Aseguradoras que aplican al regimen dado. Regimenes distintos de
  /// contributivo/subsidiado no tienen EPS en el catalogo.
  List<HealthInsurer> insurersForRegime(String? regime) => switch (regime) {
    'CONTRIBUTIVO' => insurers.where((i) => i.servesContributive).toList(),
    'SUBSIDIADO' => insurers.where((i) => i.servesSubsidized).toList(),
    _ => const [],
  };

  Patient? get patient => _patient;
  Attention? get attention => _attention;
  List<AppliedDose> get doses => _attention?.doses ?? const [];

  /// True cuando el catalogo efectivo ya se intento cargar en esta sesion
  /// (aunque haya venido vacio). Permite distinguir "cargando" de "sin
  /// vacunas habilitadas".
  bool get effectiveCatalogLoaded => _effectiveCatalogLoaded;

  /// Carga el catalogo efectivo de la institucion (una sola vez por sesion).
  Future<void> loadEffectiveCatalog() async {
    if (_effectiveCatalogLoaded) return;
    await execute((token) async {
      _effectiveVaccines = await listEffectiveCatalog(token);
      _effectiveCatalogLoaded = true;
    });
  }

  /// Carga los departamentos (una sola vez).
  Future<void> loadDepartments() async {
    if (_departments.isNotEmpty) return;
    await execute((token) async {
      _departments = await listDepartments(token);
    });
  }

  /// Carga los paises del catalogo geografico (una sola vez).
  Future<void> loadCountries() async {
    if (_countries.isNotEmpty) return;
    await execute((token) async {
      _countries = await listCountries(token);
    });
  }

  /// Carga los catalogos de referencia del wizard (una sola vez).
  Future<void> loadReferenceCatalogs() async {
    if (_referenceCatalogs.isNotEmpty) return;
    await execute((token) async {
      final catalogs = await listReferenceCatalogs(token);
      _referenceCatalogs = {
        for (final catalog in catalogs) catalog.code: catalog.options,
      };
    });
  }

  /// Carga las aseguradoras (EPS) activas (una sola vez).
  Future<void> loadInsurers() async {
    if (_insurers.isNotEmpty) return;
    await execute((token) async {
      _insurers = await listInsurers(token);
    });
  }

  /// Carga los municipios del departamento indicado.
  Future<void> loadMunicipalities(String departmentId) =>
      execute((token) async {
        _municipalities = await listMunicipalities(token, departmentId);
      });

  /// Busca pacientes por documento. Deja el resultado en [searchResults].
  /// Offline consulta el working set local; online consulta la API.
  Future<void> findPatients({
    required OfflineAccess offline,
    required String documentType,
    required String documentNumber,
  }) => execute((token) async {
    _searchResults = _isOffline(offline)
        ? await offlineRepository!.findPatients(
            documentType: documentType,
            documentNumber: documentNumber,
          )
        : await searchPatient(
            token,
            documentType: documentType,
            documentNumber: documentNumber,
          );
  });

  void selectPatient(Patient patient) {
    _patient = patient;
    _attention = null;
    notifyListeners();
  }

  /// Crea un paciente (wizard) y lo selecciona para la atencion.
  Future<Patient?> registerPatient({
    required OfflineAccess offline,
    required NewPatientInput input,
  }) async {
    Patient? created;
    await execute((token) async {
      created = _isOffline(offline)
          ? await offlineRepository!.createPatientLocal(input)
          : await createPatient(
              token,
              offline: offline,
              input: input,
              operationId: uuidV4(),
            );
      _patient = created;
      _searchResults = [created!];
    });
    return created;
  }

  /// Registra una dosis. La atencion se crea de forma perezosa en la primera
  /// dosis (con las observaciones del encuentro); las dosis siguientes se
  /// registran sobre la misma atencion. Online-first.
  Future<bool> addDose({
    required OfflineAccess offline,
    required String vaccineId,
    required String doseOptionId,
    String? observations,
    String? attentionDate,
    String? pneumococcalTypeOptionId,
    String? lotNumber,
    String? applicationDate,
    String? selectedLaboratoryId,
    String? selectedSyringeId,
    String? selectedDropperId,
    String? selectedObservationId,
    String? syringeLot,
    String? diluent,
    int? vialCount,
    String? customObservation,
  }) async {
    final patient = _patient;
    if (patient == null) {
      setError('Selecciona un paciente antes de registrar la dosis.');
      return false;
    }

    if (_isOffline(offline)) {
      final repository = offlineRepository!;
      var success = false;
      await execute((token) async {
        var attention = _attention;
        if (attention == null) {
          attention = await repository.createAttentionLocal(
            patientId: patient.id,
            observations: observations,
            attentionDate: attentionDate,
          );
          _attention = attention;
        }
        final vaccine = _vaccineById(vaccineId);
        final doseOption = vaccine == null
            ? null
            : _doseOptionById(vaccine, doseOptionId);
        final dose = await repository.registerDoseLocal(
          attentionId: attention.id,
          vaccineId: vaccineId,
          doseOptionId: doseOptionId,
          vaccineNameSnapshot: vaccine?.name ?? '',
          doseLabelSnapshot: doseOption?.displayName,
          pneumococcalTypeOptionId: pneumococcalTypeOptionId,
          lotNumber: lotNumber,
          applicationDate: applicationDate,
          selectedLaboratoryId: selectedLaboratoryId,
          selectedSyringeId: selectedSyringeId,
          selectedDropperId: selectedDropperId,
          selectedObservationId: selectedObservationId,
        );
        _attention = _withDose(attention, dose);
        success = true;
      });
      return success;
    }

    var success = false;
    await execute((token) async {
      _attention ??= await createAttention(
        token,
        offline: offline,
        patientId: patient.id,
        observations: observations,
        attentionDate: attentionDate,
        operationId: uuidV4(),
      );
      final attention = _attention!;
      final dose = await registerDose(
        token,
        attention.id,
        offline: offline,
        vaccineId: vaccineId,
        doseOptionId: doseOptionId,
        pneumococcalTypeOptionId: pneumococcalTypeOptionId,
        lotNumber: lotNumber,
        applicationDate: applicationDate,
        selectedLaboratoryId: selectedLaboratoryId,
        selectedSyringeId: selectedSyringeId,
        selectedDropperId: selectedDropperId,
        selectedObservationId: selectedObservationId,
        syringeLot: syringeLot,
        diluent: diluent,
        vialCount: vialCount,
        customObservation: customObservation,
        operationId: uuidV4(),
      );
      _attention = _withDose(attention, dose);
      success = true;
    });
    return success;
  }

  /// Actualiza los detalles del encuentro en curso (fecha de atencion, esquema
  /// completo y datos de ingreso al aplicativo PAIWEB). Online-only.
  Future<Attention?> updateAttentionDetails({
    required OfflineAccess offline,
    String? attentionDate,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? observations,
  }) async {
    final attention = _attention;
    if (attention == null) return null;
    Attention? updated;
    await execute((token) async {
      updated = await updateAttention(
        token,
        attention.id,
        offline: offline,
        version: attention.version,
        attentionDate: attentionDate,
        completeScheme: completeScheme,
        paiwebRegistered: paiwebRegistered,
        paiwebNotRegisteredReason: paiwebNotRegisteredReason,
        observations: observations,
      );
      _attention = updated;
    });
    return updated;
  }

  EffectiveVaccine? _vaccineById(String vaccineId) {
    for (final vaccine in _effectiveVaccines) {
      if (vaccine.vaccineId == vaccineId) return vaccine;
    }
    return null;
  }

  EffectiveOption? _doseOptionById(EffectiveVaccine vaccine, String doseId) {
    for (final option in vaccine.doses) {
      if (option.id == doseId) return option;
    }
    return null;
  }

  Attention _withDose(Attention attention, AppliedDose dose) => Attention(
    id: attention.id,
    patientId: attention.patientId,
    professionalId: attention.professionalId,
    status: attention.status,
    version: attention.version,
    doses: [...attention.doses, dose],
    attentionDate: attention.attentionDate,
    consecutive: attention.consecutive,
    observations: attention.observations,
  );

  /// Cierra la atencion (COMPLETED).
  Future<bool> finishAttention({required OfflineAccess offline}) async {
    final attention = _attention;
    if (attention == null) return false;
    var success = false;
    await execute((token) async {
      _attention = _isOffline(offline)
          ? await offlineRepository!.completeAttentionLocal(
              attentionId: attention.id,
            )
          : await completeAttention(token, attention.id, offline: offline);
      success = true;
    });
    return success;
  }

  /// Anula la atencion en curso con motivo.
  Future<bool> cancelAttentionFlow({
    required OfflineAccess offline,
    required String reason,
  }) async {
    final attention = _attention;
    if (attention == null) return false;
    var success = false;
    await execute((token) async {
      _attention = await cancelAttention(
        token,
        attention.id,
        offline: offline,
        reason: reason,
      );
      success = true;
    });
    return success;
  }

  /// Anula una dosis registrada en la atencion en curso.
  Future<bool> cancelDoseFlow({
    required OfflineAccess offline,
    required String doseId,
    required String reason,
  }) async {
    final attention = _attention;
    if (attention == null) return false;
    var success = false;
    await execute((token) async {
      final cancelled = await cancelDose(
        token,
        attention.id,
        doseId,
        offline: offline,
        reason: reason,
      );
      _attention = Attention(
        id: attention.id,
        patientId: attention.patientId,
        professionalId: attention.professionalId,
        status: attention.status,
        version: attention.version,
        doses: [
          for (final dose in attention.doses)
            dose.id == doseId ? cancelled : dose,
        ],
        attentionDate: attention.attentionDate,
        consecutive: attention.consecutive,
        observations: attention.observations,
      );
      success = true;
    });
    return success;
  }

  /// Limpia solo el resultado de la busqueda de paciente (deja intactos el
  /// paciente seleccionado y la atencion en curso). Se usa al entrar a la vista
  /// o al volver del alta rapida para no arrastrar busquedas anteriores.
  void clearSearch() {
    if (_searchResults.isEmpty) return;
    _searchResults = const [];
    notifyListeners();
  }

  /// Reinicia el flujo de nueva atencion (no borra el catalogo efectivo).
  void resetFlow() {
    _patient = null;
    _attention = null;
    _searchResults = const [];
    clearError();
    notifyListeners();
  }

  /// Limpia todo el estado de la sesion (al cerrar sesion o cambiar de
  /// usuario): paciente, atencion, catalogo efectivo y geografia.
  void clearSession() {
    _patient = null;
    _attention = null;
    _searchResults = const [];
    _effectiveVaccines = const [];
    _effectiveCatalogLoaded = false;
    _countries = const [];
    _departments = const [];
    _municipalities = const [];
    _referenceCatalogs = const {};
    _insurers = const [];
    clearError();
    notifyListeners();
  }

  @override
  String mapApiError(ApiException e) => e.statusCode == 409
      ? (e.message.isEmpty
            ? 'Operacion no valida en el estado actual.'
            : e.message)
      : e.message;
}
