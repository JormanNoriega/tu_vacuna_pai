import 'package:flutter/material.dart';

import '../features/admin/presentation/admin_controller.dart';
import '../features/auth/data/in_memory_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/use_cases/sign_in.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import 'theme/app_theme.dart';

class TuVacunaApp extends StatefulWidget {
  const TuVacunaApp({
    super.key,
    this.authRepository,
    this.adminController,
  });

  /// Repositorio de autenticacion. En produccion se inyecta desde [main];
  /// el valor por defecto usa un adaptador en memoria para tests y demos.
  final AuthRepository? authRepository;

  /// Controlador de la administracion global (SUPER_ADMIN). Se inyecta desde
  /// [main]; es null en tests y demos, donde la seccion de administracion no
  /// se muestra.
  final AdminController? adminController;

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
              user: _authController.user!,
              onSignOut: _authController.signOut,
              adminController: widget.adminController,
            )
          : LoginPage(controller: _authController),
    );
  }
}