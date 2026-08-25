import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'core/auth/session_manager.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final sessionManager = SessionManager(const FlutterSecureStorage());
  final authRepository = SupabaseAuthRepository(apiClient, sessionManager);

  runApp(TuVacunaApp(authRepository: authRepository));
}