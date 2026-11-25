import 'package:flutter/material.dart';

import 'connection/admin_api.dart';
import 'connection/admin_config.dart';
import 'connection/admin_session.dart';
import 'connection/session_page.dart';
import 'users/app_colors.dart';

void main() {
  try {
    final config = AdminConfig.fromEnvironment();
    final session = AdminSession(
      SupabaseAuthGateway(config.supabaseUrl.toString(), config.publishableKey),
      AdminApi(config.apiBaseUrl),
    );
    runApp(AdminWebApp(session: session));
  } on FormatException {
    runApp(const AdminWebApp());
  }
}

/// Punto de entrada aislado: todavía no habilita operaciones administrativas.
class AdminWebApp extends StatelessWidget {
  const AdminWebApp({this.session, super.key});

  final AdminSession? session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tu Vacuna PAI · Administración',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.border,
          error: AppColors.danger,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F4F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
      ),
      home: session != null
          ? SessionPage(session: session!)
          : Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tu Vacuna PAI · Administración'),
                          SizedBox(height: 16),
                          Text(
                            'Aplicación en preparación',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'La nueva aplicación administrativa aún no está '
                            'disponible. No permite iniciar sesión ni realizar '
                            'operaciones.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
