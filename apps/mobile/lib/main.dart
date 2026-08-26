import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'core/auth/session_manager.dart';
import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/app_database.dart';
import 'features/admin/data/admin_repository_impl.dart';
import 'features/admin/domain/use_cases/create_institution.dart';
import 'features/admin/domain/use_cases/create_institution_admin.dart';
import 'features/admin/domain/use_cases/list_institutions.dart';
import 'features/admin/presentation/admin_controller.dart';
import 'features/auth/data/local_session_store.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/users/data/users_repository_impl.dart';
import 'features/users/domain/use_cases/create_vaccinator.dart';
import 'features/users/domain/use_cases/list_users.dart';
import 'features/users/presentation/users_controller.dart';

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
  );

  final usersRepository = UsersRepositoryImpl(apiClient, appDatabase);
  final usersController = UsersController(
    sessionManager: sessionManager,
    createVaccinator: CreateVaccinator(usersRepository),
    listUsers: ListUsers(usersRepository),
  );

  runApp(TuVacunaApp(
    authRepository: authRepository,
    adminController: adminController,
    usersController: usersController,
  ));
}