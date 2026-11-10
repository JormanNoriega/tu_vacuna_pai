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
    if (_profile?.patient.id != patientId) {
      _profile = null;
      _attentions = const [];
    }
    clearError();

    // 1. Respaldo offline preparado si ya esta en SQLite
    PatientProfile? localProfile;
    List<Attention> localAttentions = const [];
    if (database != null) {
      final localPatient = await database!.patientLocalById(patientId);
      if (localPatient != null) {
        localProfile = _buildProfileFromLocal(localPatient);
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
        localAttentions = loadedAtts;
      }
    }

    var ok = false;
    await execute((token) async {
      try {
        Future<List<Attention>> fetchAttentions() async {
          try {
            return await listPatientAttentions(token, patientId);
          } catch (_) {
            return const [];
          }
        }

        Future<List<GeoCountry>> fetchCountries() async {
          if (_countries.isNotEmpty) return _countries;
          try {
            return await listCountries(token);
          } catch (_) {
            return const [];
          }
        }

        Future<List<GeoDepartment>> fetchDepartments() async {
          if (_departments.isNotEmpty) return _departments;
          try {
            return await listDepartments(token);
          } catch (_) {
            return const [];
          }
        }

        Future<List<GeoMunicipality>> fetchMunicipalities(String deptId) async {
          if (_municipalities.isNotEmpty) return _municipalities;
          try {
            return await listMunicipalities(token, deptId);
          } catch (_) {
            return const [];
          }
        }

        final remote = await getPatient(token, patientId);
        final deptId = (remote.addresses.isNotEmpty)
            ? remote.addresses.first.departmentId
            : null;

        final results = await Future.wait([
          fetchAttentions(),
          fetchCountries(),
          fetchDepartments(),
          if (deptId != null) fetchMunicipalities(deptId),
        ]);

        _attentions = results[0] as List<Attention>;
        if (_countries.isEmpty) _countries = results[1] as List<GeoCountry>;
        if (_departments.isEmpty) _departments = results[2] as List<GeoDepartment>;
        if (deptId != null && _municipalities.isEmpty && results.length > 3) {
          _municipalities = results[3] as List<GeoMunicipality>;
        }

        _profile = remote;
        ok = true;
      } catch (e) {
        if (localProfile != null) {
          _profile = localProfile;
          _attentions = localAttentions;
          ok = true;
          return;
        }
        rethrow;
      }
    });

    if (_profile == null && localProfile != null) {
      _profile = localProfile;
      _attentions = localAttentions;
      ok = true;
      notifyListeners();
    }

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
        birthCountryId: '170',
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
            countryId: '170',
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
