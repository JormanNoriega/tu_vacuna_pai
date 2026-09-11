import 'package:flutter/material.dart';

import '../core/network/network_info.dart';
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
import '../features/catalogs/presentation/catalog_controller.dart';
import '../features/attentions/presentation/attention_controller.dart';
import '../features/attentions/presentation/history_controller.dart';
import '../features/patients/presentation/patient_detail_controller.dart';
import 'theme/app_theme.dart';

class TuVacunaApp extends StatefulWidget {
  const TuVacunaApp({
    super.key,
    this.authRepository,
    this.adminController,
    this.usersController,
    this.catalogController,
    this.attentionController,
    this.historyController,
    this.patientDetailController,
    this.networkInfo,
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
  final CatalogController? catalogController;

  /// Controlador del flujo clinico (nueva atencion e historial).
  final AttentionController? attentionController;

  /// Controlador del historial de atenciones.
  final HistoryController? historyController;

  /// Controlador de la ficha del paciente (ver + editar).
  final PatientDetailController? patientDetailController;

  /// Conectividad del dispositivo para ajustar en tiempo real la etiqueta del
  /// banner offline. Solo afecta lo visual; la autorizacion la define el
  /// estado de sesion. Null en tests y demos (sin listener).
  final NetworkInfo? networkInfo;

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
  )..addListener(_handleAuthChanged);

  /// Id del usuario de la sesion actual. Se usa para limpiar el estado en
  /// memoria de los controladores cuando cambia el usuario (logout o login con
  /// otra cuenta), evitando que se arrastren datos de la cuenta anterior.
  String? _sessionUserId;

  void _handleAuthChanged() {
    final userId = _authController.user?.id;
    if (userId != _sessionUserId) {
      _sessionUserId = userId;
      _resetSessionState();
    }
    setState(() {});
  }

  void _resetSessionState() {
    widget.adminController?.clearSession();
    widget.usersController?.clearSession();
    widget.catalogController?.clearSession();
    widget.attentionController?.clearSession();
    widget.historyController?.clearSession();
    widget.patientDetailController?.clearSession();
  }

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
      ..removeListener(_handleAuthChanged)
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
        catalogController: widget.catalogController,
        attentionController: widget.attentionController,
        historyController: widget.historyController,
        patientDetailController: widget.patientDetailController,
        sessionStatus: _authController.status,
        offlineReason: _authController.offlineReason,
        networkInfo: widget.networkInfo,
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
