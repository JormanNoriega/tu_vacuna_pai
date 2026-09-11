import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'core/auth/session_manager.dart';
import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/app_database.dart';
import 'features/admin/application/use_cases/list_institution_admins.dart';
import 'features/admin/data/admin_repository_impl.dart';
import 'features/admin/domain/use_cases/clone_catalog_to_institution.dart';
import 'features/admin/domain/use_cases/create_institution.dart';
import 'features/admin/domain/use_cases/create_institution_admin.dart';
import 'features/admin/domain/use_cases/list_institutions.dart';
import 'features/admin/domain/use_cases/update_institution_config.dart';
import 'features/admin/presentation/admin_controller.dart';
import 'features/auth/data/local_session_store.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/users/application/use_cases/update_user.dart';
import 'features/users/data/users_repository_impl.dart';
import 'features/users/domain/use_cases/create_vaccinator.dart';
import 'features/users/domain/use_cases/list_users.dart';
import 'features/users/presentation/users_controller.dart';
import 'features/catalogs/data/catalog_repository_impl.dart';
import 'features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'features/catalogs/presentation/catalog_controller.dart';
import 'features/patients/data/patients_repository_impl.dart';
import 'features/patients/domain/use_cases/create_patient.dart';
import 'features/patients/domain/use_cases/patient_profile_use_cases.dart';
import 'features/patients/domain/use_cases/search_patient.dart';
import 'features/patients/presentation/patient_detail_controller.dart';
import 'features/attentions/data/attentions_repository_impl.dart';
import 'features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'features/attentions/presentation/attention_controller.dart';
import 'features/attentions/presentation/history_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  final secureStorage = const FlutterSecureStorage();
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final sessionManager = SessionManager(secureStorage);
  final networkInfo = ConnectivityNetworkInfo();
  final appDatabase = await AppDatabase.open(secureStorage);
  final localSessionStore = LocalSessionStore(appDatabase);
  final authRepository = SupabaseAuthRepository(
    apiClient,
    sessionManager,
    localSessionStore,
    networkInfo,
  );

  final adminRepository = AdminRepositoryImpl(apiClient);
  final adminController = AdminController(
    sessionManager: sessionManager,
    createInstitution: CreateInstitution(adminRepository),
    listInstitutions: ListInstitutions(adminRepository),
    createInstitutionAdmin: CreateInstitutionAdmin(adminRepository),
    updateInstitutionConfig: UpdateInstitutionConfig(adminRepository),
    listInstitutionAdmins: ListInstitutionAdmins(
      repository: adminRepository,
      listInstitutions: ListInstitutions(adminRepository),
    ),
    cloneCatalogToInstitution: CloneCatalogToInstitution(adminRepository),
  );

  final usersRepository = UsersRepositoryImpl(apiClient, appDatabase);
  final usersController = UsersController(
    sessionManager: sessionManager,
    createVaccinator: CreateVaccinator(usersRepository),
    listUsers: ListUsers(usersRepository),
    updateUser: UpdateUser(usersRepository),
  );
  final catalogRepository = CatalogRepositoryImpl(apiClient, appDatabase);
  final catalogController = CatalogController(
    sessionManager: sessionManager,
    repository: catalogRepository,
    listVaccines: ListVaccines(catalogRepository),
    saveVaccine: SaveVaccine(catalogRepository),
    toggle: ToggleInstitutionVaccine(catalogRepository),
    listAvailableVaccines: ListAvailableInstitutionVaccines(catalogRepository),
  );

  final patientsRepository = PatientsRepositoryImpl(apiClient);
  final attentionsRepository = AttentionsRepositoryImpl(apiClient);
  final attentionController = AttentionController(
    sessionManager: sessionManager,
    searchPatient: SearchPatient(patientsRepository),
    createPatient: CreatePatient(patientsRepository),
    listEffectiveCatalog: ListEffectiveCatalog(catalogRepository),
    listDepartments: ListDepartments(catalogRepository),
    listMunicipalities: ListMunicipalities(catalogRepository),
    createAttention: CreateAttention(attentionsRepository),
    registerDose: RegisterDose(attentionsRepository),
    completeAttention: CompleteAttention(attentionsRepository),
    cancelAttention: CancelAttention(attentionsRepository),
    cancelDose: CancelDose(attentionsRepository),
  );
  final historyController = HistoryController(
    sessionManager: sessionManager,
    searchPatient: SearchPatient(patientsRepository),
    listPatientAttentions: ListPatientAttentions(attentionsRepository),
  );
  final patientDetailController = PatientDetailController(
    sessionManager: sessionManager,
    getPatient: GetPatient(patientsRepository),
    updateDemographics: UpdatePatientDemographics(patientsRepository),
    updateContact: UpdatePatientContact(patientsRepository),
    updateMedicalHistories: UpdatePatientMedicalHistories(patientsRepository),
    listDepartments: ListDepartments(catalogRepository),
    listMunicipalities: ListMunicipalities(catalogRepository),
  );

  runApp(
    TuVacunaApp(
      authRepository: authRepository,
      adminController: adminController,
      usersController: usersController,
      catalogController: catalogController,
      attentionController: attentionController,
      historyController: historyController,
      patientDetailController: patientDetailController,
      networkInfo: networkInfo,
    ),
  );
}
