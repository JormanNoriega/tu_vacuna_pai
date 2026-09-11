import '../../../core/auth/offline_access.dart';
import '../../../core/presentation/async_controller.dart';
import '../../catalogs/domain/entities/geo.dart';
import '../../catalogs/domain/use_cases/catalog_use_cases.dart';
import '../domain/entities/new_patient.dart';
import '../domain/entities/patient_profile.dart';
import '../domain/use_cases/patient_profile_use_cases.dart';

/// Controlador de la ficha del paciente: carga el perfil completo y permite
/// editar demografia, contacto/direccion y antecedentes (online-first).
class PatientDetailController extends AsyncController {
  PatientDetailController({
    required super.sessionManager,
    required this.getPatient,
    required this.updateDemographics,
    required this.updateContact,
    required this.updateMedicalHistories,
    required this.listDepartments,
    required this.listMunicipalities,
  });

  final GetPatient getPatient;
  final UpdatePatientDemographics updateDemographics;
  final UpdatePatientContact updateContact;
  final UpdatePatientMedicalHistories updateMedicalHistories;
  final ListDepartments listDepartments;
  final ListMunicipalities listMunicipalities;

  PatientProfile? _profile;
  List<GeoDepartment> _departments = const [];
  List<GeoMunicipality> _municipalities = const [];

  PatientProfile? get profile => _profile;
  List<GeoDepartment> get departments => List.unmodifiable(_departments);
  List<GeoMunicipality> get municipalities =>
      List.unmodifiable(_municipalities);

  Future<bool> load(String patientId) async {
    var ok = false;
    await execute((token) async {
      _profile = await getPatient(token, patientId);
      ok = true;
    });
    return ok;
  }

  Future<void> loadDepartments() async {
    if (_departments.isNotEmpty) return;
    await execute((token) async {
      _departments = await listDepartments(token);
    });
  }

  Future<void> loadMunicipalities(String departmentId) =>
      execute((token) async {
        _municipalities = await listMunicipalities(token, departmentId);
      });

  Future<bool> saveDemographics({
    required OfflineAccess offline,
    String? gender,
    String? ethnicity,
    String? educationLevel,
  }) async {
    final profile = _profile;
    if (profile == null) return false;
    var ok = false;
    await execute((token) async {
      _profile = await updateDemographics(
        token,
        profile.patient.id,
        offline: offline,
        gender: gender,
        ethnicity: ethnicity,
        educationLevel: educationLevel,
      );
      ok = true;
    });
    return ok;
  }

  Future<bool> saveContact({
    required OfflineAccess offline,
    required List<NewPatientContact> contacts,
    required List<NewPatientAddress> addresses,
  }) async {
    final profile = _profile;
    if (profile == null) return false;
    var ok = false;
    await execute((token) async {
      _profile = await updateContact(
        token,
        profile.patient.id,
        offline: offline,
        contacts: contacts,
        addresses: addresses,
      );
      ok = true;
    });
    return ok;
  }

  Future<bool> saveMedicalHistories({
    required OfflineAccess offline,
    required List<NewPatientMedicalHistory> histories,
  }) async {
    final profile = _profile;
    if (profile == null) return false;
    var ok = false;
    await execute((token) async {
      _profile = await updateMedicalHistories(
        token,
        profile.patient.id,
        offline: offline,
        histories: histories,
      );
      ok = true;
    });
    return ok;
  }

  void clearSession() {
    _profile = null;
    _municipalities = const [];
    clearError();
    notifyListeners();
  }
}
