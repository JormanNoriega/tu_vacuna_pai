import 'package:flutter/material.dart';

import '../features/admin/presentation/admin_controller.dart';
import '../features/auth/data/in_memory_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/use_cases/restore_session.dart';
import '../features/auth/domain/use_cases/sign_in.dart';
import '../features/auth/domain/use_cases/sign_out.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/users/presentation/users_controller.dart';
import 'theme/app_theme.dart';

class TuVacunaApp extends StatefulWidget {
  const TuVacunaApp({
    super.key,
    this.authRepository,
    this.adminController,
    this.usersController,
  });

  /// Repositorio de autenticacion. En produccion se inyecta desde [main];
  /// el valor por defecto usa un adaptador en memoria para tests y demos.
  final AuthRepository? authRepository;

  /// Controlador de la administracion global (SUPER_ADMIN). Se inyecta desde
  /// [main]; es null en tests y demos, donde la seccion de administracion no
  /// se muestra.
  final AdminController? adminController;

  /// Controlador de la gestion de usuarios de institucion (ADMIN_INSTITUTION).
  /// Se inyecta desde [main]; es null en tests y demos.
  final UsersController? usersController;

  @override
  State<TuVacunaApp> createState() => _TuVacunaAppState();
}

class _TuVacunaAppState extends State<TuVacunaApp> {
  late final AuthController _authController = AuthController(
    signIn: SignIn(widget.authRepository ?? InMemoryAuthRepository()),
    restoreSession: RestoreSession(
      widget.authRepository ?? InMemoryAuthRepository(),
    ),
    signOut: SignOut(widget.authRepository ?? InMemoryAuthRepository()),
  )..addListener(_onAuthChanged);

  void _onAuthChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    // Restaura la sesion persistida (online o dentro de la ventana offline)
    // antes de decidir si se muestra el login o el dashboard.
    _authController.restoreSession();
  }

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
      home: _home(),
    );
  }

  Widget _home() {
    if (_authController.isRestoring) {
      return const _SplashPage();
    }

    final user = _authController.user;
    if (user != null) {
      return DashboardPage(
        user: user,
        onSignOut: _authController.signOut,
        adminController: widget.adminController,
        usersController: widget.usersController,
        sessionStatus: _authController.status,
      );
    }
    return LoginPage(controller: _authController);
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vaccines_rounded, size: 64, color: AppColors.primary),
            SizedBox(height: 24),
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
