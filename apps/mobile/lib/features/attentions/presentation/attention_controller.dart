import '../../../core/auth/offline_access.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/async_controller.dart';
import '../../../core/utils/uuid.dart';
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
/// atencion. Online-first: ninguna escritura se confirma hasta la respuesta del
/// servidor.
class AttentionController extends AsyncController {
  AttentionController({
    required super.sessionManager,
    required this.searchPatient,
    required this.createPatient,
    required this.listEffectiveCatalog,
    required this.listDepartments,
    required this.listMunicipalities,
    required this.createAttention,
    required this.registerDose,
    required this.completeAttention,
    required this.cancelAttention,
    required this.cancelDose,
  });

  final SearchPatient searchPatient;
  final CreatePatient createPatient;
  final ListEffectiveCatalog listEffectiveCatalog;
  final ListDepartments listDepartments;
  final ListMunicipalities listMunicipalities;
  final CreateAttention createAttention;
  final RegisterDose registerDose;
  final CompleteAttention completeAttention;
  final CancelAttention cancelAttention;
  final CancelDose cancelDose;

  List<EffectiveVaccine> _effectiveVaccines = const [];
  List<Patient> _searchResults = const [];
  List<GeoDepartment> _departments = const [];
  List<GeoMunicipality> _municipalities = const [];
  Patient? _patient;
  Attention? _attention;

  List<EffectiveVaccine> get effectiveVaccines =>
      List.unmodifiable(_effectiveVaccines);
  List<Patient> get searchResults => List.unmodifiable(_searchResults);
  List<GeoDepartment> get departments => List.unmodifiable(_departments);
  List<GeoMunicipality> get municipalities =>
      List.unmodifiable(_municipalities);
  Patient? get patient => _patient;
  Attention? get attention => _attention;
  List<AppliedDose> get doses => _attention?.doses ?? const [];

  /// Carga el catalogo efectivo de la institucion (una sola vez).
  Future<void> loadEffectiveCatalog() async {
    if (_effectiveVaccines.isNotEmpty) return;
    await execute((token) async {
      _effectiveVaccines = await listEffectiveCatalog(token);
    });
  }

  /// Carga los departamentos (una sola vez).
  Future<void> loadDepartments() async {
    if (_departments.isNotEmpty) return;
    await execute((token) async {
      _departments = await listDepartments(token);
    });
  }

  /// Carga los municipios del departamento indicado.
  Future<void> loadMunicipalities(String departmentId) =>
      execute((token) async {
        _municipalities = await listMunicipalities(token, departmentId);
      });

  /// Busca pacientes por documento. Deja el resultado en [searchResults].
  Future<void> findPatients({
    required String documentType,
    required String documentNumber,
  }) => execute((token) async {
    _searchResults = await searchPatient(
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
      created = await createPatient(
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
    String? pneumococcalTypeOptionId,
    String? lotNumber,
    String? applicationDate,
    String? selectedLaboratoryId,
    String? selectedSyringeId,
    String? selectedDropperId,
    String? selectedObservationId,
  }) async {
    final patient = _patient;
    if (patient == null) {
      setError('Selecciona un paciente antes de registrar la dosis.');
      return false;
    }
    var success = false;
    await execute((token) async {
      _attention ??= await createAttention(
        token,
        offline: offline,
        patientId: patient.id,
        observations: observations,
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
        operationId: uuidV4(),
      );
      _attention = Attention(
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
      success = true;
    });
    return success;
  }

  /// Cierra la atencion (COMPLETED).
  Future<bool> finishAttention({required OfflineAccess offline}) async {
    final attention = _attention;
    if (attention == null) return false;
    var success = false;
    await execute((token) async {
      _attention = await completeAttention(
        token,
        attention.id,
        offline: offline,
      );
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

  /// Reinicia el flujo de nueva atencion (no borra el catalogo efectivo).
  void resetFlow() {
    _patient = null;
    _attention = null;
    _searchResults = const [];
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
