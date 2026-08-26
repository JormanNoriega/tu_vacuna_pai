import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'core/auth/session_manager.dart';
import 'core/network/api_client.dart';
import 'features/admin/data/admin_repository_impl.dart';
import 'features/admin/domain/use_cases/create_institution.dart';
import 'features/admin/domain/use_cases/create_institution_admin.dart';
import 'features/admin/domain/use_cases/list_institutions.dart';
import 'features/admin/presentation/admin_controller.dart';
import 'features/auth/data/supabase_auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final sessionManager = SessionManager(const FlutterSecureStorage());
  final authRepository = SupabaseAuthRepository(apiClient, sessionManager);

  final adminRepository = AdminRepositoryImpl(apiClient);
  final adminController = AdminController(
    sessionManager: sessionManager,
    createInstitution: CreateInstitution(adminRepository),
    listInstitutions: ListInstitutions(adminRepository),
    createInstitutionAdmin: CreateInstitutionAdmin(adminRepository),
  );

  runApp(TuVacunaApp(
    authRepository: authRepository,
    adminController: adminController,
  ));
}