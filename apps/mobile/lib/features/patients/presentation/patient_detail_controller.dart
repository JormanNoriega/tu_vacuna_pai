import '../../../core/auth/offline_access.dart';
import '../../../core/presentation/async_controller.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/synchronization/clinical_offline_repository.dart';
import '../../attentions/domain/entities/attention.dart';
import '../../attentions/domain/use_cases/attentions_use_cases.dart';
import '../../catalogs/domain/entities/geo.dart';
import '../../catalogs/domain/use_cases/catalog_use_cases.dart';
import '../domain/entities/new_patient.dart';
import '../domain/entities/patient.dart';
import '../domain/entities/patient_profile.dart';
import '../domain/use_cases/patient_profile_use_cases.dart';

/// Controlador de la ficha del paciente: carga el perfil completo y permite
/// editar demografia, contacto/direccion y antecedentes (online-first con respaldo offline).
class PatientDetailController extends AsyncController {
  PatientDetailController({
    required super.sessionManager,
    required this.getPatient,
    required this.updateDemographics,
    required this.updateContact,
    required this.updateMedicalHistories,
    required this.listCountries,
    required this.listDepartments,
    required this.listMunicipalities,
    required this.listPatientAttentions,
    this.database,
    this.offlineRepository,
  });

  final GetPatient getPatient;
  final UpdatePatientDemographics updateDemographics;
  final UpdatePatientContact updateContact;
  final UpdatePatientMedicalHistories updateMedicalHistories;
  final ListCountries listCountries;
  final ListDepartments listDepartments;
  final ListMunicipalities listMunicipalities;
  final ListPatientAttentions listPatientAttentions;
  final AppDatabase? database;
  final ClinicalOfflineRepository? offlineRepository;

  PatientProfile? _profile;
  List<GeoCountry> _countries = const [];
  List<GeoDepartment> _departments = const [];
  List<GeoMunicipality> _municipalities = const [];
  List<Attention> _attentions = const [];

  PatientProfile? get profile => _profile;
  List<GeoCountry> get countries => List.unmodifiable(_countries);
  List<GeoDepartment> get departments => List.unmodifiable(_departments);
  List<GeoMunicipality> get municipalities =>
      List.unmodifiable(_municipalities);
  List<Attention> get attentions => List.unmodifiable(_attentions);

  Future<bool> load(String patientId) async {
    // 1. Respaldo offline: si existe en SQLite, se ensambla el perfil
    if (database != null) {
      final localPatient = await database!.patientLocalById(patientId);
      if (localPatient != null) {
        _profile = _buildProfileFromLocal(localPatient);
        final localAtts = await database!.attentionsLocalByPatient(patientId);
        final loadedAtts = <Attention>[];
        for (final a in localAtts) {
          try {
            final full = offlineRepository != null
                ? await offlineRepository!.attentionLocalWithDoses(a.id)
                : Attention(
                    id: a.id,
                    patientId: a.patientId,
                    professionalId: a.vaccinatorId ?? '',
                    status: a.status,
                    version: 1,
                    doses: const [],
                  );
            loadedAtts.add(full);
          } catch (_) {}
        }
        _attentions = loadedAtts;
        notifyListeners();
      }
    }

    var ok = _profile != null;
    await execute((token) async {
      try {
        final remote = await getPatient(token, patientId);
        _profile = remote;
        ok = true;
        try {
          _attentions = await listPatientAttentions(token, patientId);
        } catch (_) {}
      } catch (e) {
        if (_profile != null) {
          return;
        }
        rethrow;
      }
    });

    if (_profile != null && error != null) {
      clearError();
    }
    return ok;
  }

  PatientProfile _buildProfileFromLocal(PatientsLocalData row) {
    return PatientProfile(
      patient: Patient(
        id: row.id,
        documentType: row.documentType,
        documentNumber: row.documentNumber,
        firstName: row.firstName,
        lastName: row.lastName,
        birthDate: row.birthDate,
        sex: row.sex ?? 'UNKNOWN',
        status: 'ACTIVE',
      ),
      demographics: (row.gender != null)
          ? PatientDemographics(gender: row.gender)
          : null,
      contacts: [
        if (row.phone != null && row.phone!.isNotEmpty)
          PatientContact(
            id: 'local-phone-${row.id}',
            type: 'PHONE',
            value: row.phone!,
            phoneKind: 'CELLPHONE',
            primary: true,
          ),
        if (row.email != null && row.email!.isNotEmpty)
          PatientContact(
            id: 'local-email-${row.id}',
            type: 'EMAIL',
            value: row.email!,
            primary: false,
          ),
      ],
      addresses: [
        if ((row.addressLine != null && row.addressLine!.isNotEmpty) ||
            row.addressDepartment != null ||
            row.addressMunicipality != null)
          PatientAddress(
            id: 'local-addr-${row.id}',
            street: row.addressLine,
            departmentId: row.addressDepartment,
            municipalityId: row.addressMunicipality,
            primary: true,
          ),
      ],
    );
  }

  Future<void> loadCountries() async {
    if (_countries.isNotEmpty) return;
    try {
      final session = await sessionManager.loadSession();
      final token = session?.accessToken;
      if (token != null) {
        _countries = await listCountries(token);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadDepartments() async {
    if (_departments.isNotEmpty) return;
    try {
      final session = await sessionManager.loadSession();
      final token = session?.accessToken;
      if (token != null) {
        _departments = await listDepartments(token);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadMunicipalities(String departmentId) async {
    try {
      final session = await sessionManager.loadSession();
      final token = session?.accessToken;
      if (token != null) {
        _municipalities = await listMunicipalities(token, departmentId);
        notifyListeners();
      }
    } catch (_) {}
  }

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
    _countries = const [];
    _municipalities = const [];
    _attentions = const [];
    clearError();
    notifyListeners();
  }
}
