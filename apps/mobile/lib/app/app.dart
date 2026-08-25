import 'package:flutter/material.dart';

import '../features/auth/data/in_memory_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/use_cases/sign_in.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import 'theme/app_theme.dart';

class TuVacunaApp extends StatefulWidget {
  const TuVacunaApp({super.key, this.authRepository});

  /// Repositorio de autenticacion. En produccion se inyecta desde [main];
  /// el valor por defecto usa un adaptador en memoria para tests y demos.
  final AuthRepository? authRepository;

  @override
  State<TuVacunaApp> createState() => _TuVacunaAppState();
}

class _TuVacunaAppState extends State<TuVacunaApp> {
  late final AuthController _authController = AuthController(
    signIn: SignIn(widget.authRepository ?? InMemoryAuthRepository()),
  )..addListener(_onAuthChanged);

  void _onAuthChanged() => setState(() {});

  @override
  void dispose() {
    _authController
      ..removeListener(_onAuthChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tu Vacuna PAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _authController.isAuthenticated
          ? DashboardPage(
              userName: _authController.userName,
              onSignOut: _authController.signOut,
            )
          : LoginPage(controller: _authController),
    );
  }
}
