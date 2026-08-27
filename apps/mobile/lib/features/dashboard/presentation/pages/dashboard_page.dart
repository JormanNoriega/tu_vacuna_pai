import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/network/network_info.dart';
import '../../../admin/presentation/admin_controller.dart';
import '../../../admin/presentation/pages/admin_page.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/domain/entities/session_restore_result.dart';
import '../../../users/presentation/pages/users_page.dart';
import '../../../users/presentation/users_controller.dart';
import '../../../catalogs/presentation/catalog_controller.dart';
import '../../../catalogs/presentation/pages/catalog_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.user,
    required this.onSignOut,
    this.adminController,
    this.usersController,
    this.catalogController,
    this.sessionStatus = SessionStatus.signedIn,
    this.offlineReason,
    this.networkInfo,
    super.key,
  });

  final AuthUser user;
  final VoidCallback onSignOut;

  /// Controlador de administracion global. Solo se usa cuando [user] es
  /// SUPER_ADMIN.
  final AdminController? adminController;

  /// Controlador de la gestion de usuarios de institucion. Solo se usa cuando
  /// [user] tiene el permiso USER_MANAGE (ADMIN_INSTITUTION).
  final UsersController? usersController;
  final CatalogController? catalogController;

  /// Estado de la sesion restaurada. Define si se muestra un banner de modo
  /// offline y que operaciones de escritura estan permitidas.
  final SessionStatus sessionStatus;

  /// Razon de la ventana offline (noNetwork / backendUnavailable). Solo afecta
  /// la etiqueta del banner; la autorizacion vive en [sessionStatus].
  final OfflineReason? offlineReason;

  /// Conectividad del dispositivo para ajustar la etiqueta del banner en
  /// tiempo real. Null en tests (sin listener).
  final NetworkInfo? networkInfo;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  /// Razon visual del banner, ajustable en vivo por la conectividad del
  /// dispositivo (no re-autoriza ni re-valida).
  OfflineReason? _liveReason;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _liveReason = widget.offlineReason;
    final networkInfo = widget.networkInfo;
    if (networkInfo != null) {
      _connectivitySub = networkInfo.connectivityChanges.listen(
        _onConnectivityChanged,
      );
    }
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offlineReason != widget.offlineReason) {
      _liveReason = widget.offlineReason;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  /// Solo etiqueta visual: con conectividad del dispositivo el motivo de la
  /// ventana es "backend no disponible"; sin red, "sin conexion a Internet".
  void _onConnectivityChanged(bool connected) {
    if (!mounted) return;
    setState(() {
      _liveReason = connected
          ? OfflineReason.backendUnavailable
          : OfflineReason.noNetwork;
    });
  }

  List<_DashboardDestination> get _destinations =>
      [
            const _DashboardDestination(
              icon: Icons.space_dashboard_outlined,
              selectedIcon: Icons.space_dashboard_rounded,
              label: 'Inicio',
            ),
            const _DashboardDestination(
              icon: Icons.person_add_alt_1_outlined,
              selectedIcon: Icons.person_add_alt_1_rounded,
              label: 'Nueva atencion',
              requiredPermission: 'ATTENTION_CREATE',
            ),
            const _DashboardDestination(
              icon: Icons.history_rounded,
              selectedIcon: Icons.history_rounded,
              label: 'Historial',
              requiredPermission: 'ATTENTION_READ',
            ),
            const _DashboardDestination(
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              label: 'Inventario',
              requiredPermissions: [
                'CATALOG_GLOBAL_READ',
                'CATALOG_CONFIG_READ',
              ],
            ),
            const _DashboardDestination(
              icon: Icons.admin_panel_settings_outlined,
              selectedIcon: Icons.admin_panel_settings_rounded,
              label: 'Administracion',
              requiredPermission: 'USER_MANAGE',
              isUsersManagement: true,
            ),
          ]
          .where(
            (destination) =>
                destination.requiredPermission == null &&
                    (destination.requiredPermissions.isEmpty ||
                        destination.requiredPermissions.any(
                          widget.user.hasPermission,
                        )) ||
                (destination.requiredPermission != null &&
                    widget.user.hasPermission(destination.requiredPermission!)),
          )
          .toList();

  bool get _isSuperAdmin => widget.user.hasRole('SUPER_ADMIN');

  bool get _isSuperAdminView => _isSuperAdmin && widget.adminController != null;

  OfflineAccess get _offline => OfflineAccess(
    status: widget.sessionStatus,
    permissions: widget.user.permissions,
  );

  Widget _buildContent() {
    if (_isSuperAdminView) {
      return AdminPage(controller: widget.adminController!, offline: _offline);
    }

    if (_destinations[_selectedIndex].isUsersManagement &&
        widget.usersController != null) {
      return UsersPage(
        controller: widget.usersController!,
        institutionId: widget.user.institution.id,
        offline: _offline,
      );
    }

    if (_destinations[_selectedIndex].isCatalog &&
        widget.catalogController != null) {
      return CatalogPage(
        user: widget.user,
        controller: widget.catalogController!,
        offline: _offline,
      );
    }

    return _DashboardContent(
      userName: widget.user.name,
      permissions: widget.user.permissions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = MediaQuery.sizeOf(context).width >= 900;
    final content = _buildContent();
    final body = switch (widget.sessionStatus) {
      SessionStatus.offlineLocked => Column(
        children: [
          const _OfflineLockedBanner(),
          Expanded(child: content),
        ],
      ),
      SessionStatus.offlineAuthorized => Column(
        children: [
          _OfflineModeBanner(reason: _liveReason ?? OfflineReason.noNetwork),
          Expanded(child: content),
        ],
      ),
      SessionStatus.signedIn || SessionStatus.signedOut => content,
    };

    // Para SUPER_ADMIN la vista es exclusivamente de administracion: no se
    // muestran la barra de navegacion ni las acciones operativas de vacunador.
    if (_isSuperAdminView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tu Vacuna PAI'),
          actions: [
            if (widget.catalogController != null)
              IconButton(
                tooltip: 'Inventario',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CatalogPage(
                      user: widget.user,
                      controller: widget.catalogController!,
                      offline: _offline,
                    ),
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
              ),
            IconButton(
              tooltip: 'Cerrar sesion',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu Vacuna PAI'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isExpanded)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: isExpanded
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }
}

class _DashboardDestination {
  const _DashboardDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.requiredPermission,
    this.requiredPermissions = const [],
    this.isUsersManagement = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? requiredPermission;
  final List<String> requiredPermissions;

  /// True cuando el destino corresponde a la gestion de usuarios de la
  /// institucion (ADMIN_INSTITUTION).
  final bool isUsersManagement;

  bool get isCatalog => label == 'Inventario';
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.userName, required this.permissions});

  final String userName;
  final List<String> permissions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 700 ? 32.0 : 16.0;
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Buenos dias',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: AppColors.slate),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 28),
                  const _SyncBanner(),
                  const SizedBox(height: 24),
                  _StatsGrid(columns: columns),
                  const SizedBox(height: 32),
                  Text(
                    'Acciones frecuentes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _ActionsGrid(
                    columns: columns == 1 ? 2 : 4,
                    permissions: permissions,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_done_rounded, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datos protegidos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tu informacion se guarda cifrada en este dispositivo '
                    'y disponible sin conexion.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _OfflineModeBanner extends StatelessWidget {
  const _OfflineModeBanner({required this.reason});

  final OfflineReason reason;

  @override
  Widget build(BuildContext context) {
    final noNetwork = reason == OfflineReason.noNetwork;
    final color = noNetwork ? AppColors.primary : AppColors.warning;
    final title = noNetwork
        ? 'Sin conexion a Internet'
        : 'Servidor no disponible';
    final subtitle = noNetwork
        ? 'Trabajando con datos locales. La informacion se sincronizara '
              'cuando haya conexion.'
        : 'Los datos se guardaran localmente y se sincronizaran cuando el '
              'servidor vuelva a estar disponible.';
    final icon = noNetwork ? Icons.cloud_off_rounded : Icons.dns_rounded;

    return Card(
      margin: const EdgeInsets.all(16),
      color: color.withValues(alpha: .1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineLockedBanner extends StatelessWidget {
  const _OfflineLockedBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: AppColors.warning.withValues(alpha: .12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo solo lectura',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'La ventana offline vencio. Conectate a internet e inicia '
                    'sesion de nuevo para seguir registrando.',
                    style: TextStyle(color: AppColors.slate, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    // Datos reales en cero hasta que el modulo clinico los alimente. Cuando
    // exista, estos contadores se computan SIEMPRE acotados a la institucion
    // del actor (misma regla de alcance que el backend).
    const stats = [
      (
        icon: Icons.people_alt_outlined,
        value: '0',
        label: 'Pacientes atendidos',
        color: AppColors.primary,
      ),
      (
        icon: Icons.vaccines_outlined,
        value: '0',
        label: 'Dosis aplicadas',
        color: AppColors.success,
      ),
      (
        icon: Icons.pending_actions_rounded,
        value: '0',
        label: 'Pendientes de sync',
        color: AppColors.warning,
      ),
    ];
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: columns == 1 ? 3.5 : 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final stat in stats)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat.icon, color: stat.color),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat.value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.label,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  const _ActionsGrid({required this.columns, required this.permissions});

  final int columns;
  final List<String> permissions;

  @override
  Widget build(BuildContext context) {
    const allActions = [
      (
        icon: Icons.person_add_alt_1_rounded,
        label: 'Nueva atencion',
        description: 'Registrar un paciente',
        primary: true,
        requiredPermission: 'ATTENTION_CREATE',
      ),
      (
        icon: Icons.search_rounded,
        label: 'Buscar paciente',
        description: 'Consultar historial',
        primary: false,
        requiredPermission: 'PATIENT_READ',
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Ver inventario',
        description: 'Consultar existencias',
        primary: false,
        requiredPermission: 'INVENTORY_READ',
      ),
      (
        icon: Icons.admin_panel_settings_rounded,
        label: 'Administracion',
        description: 'Instituciones y usuarios',
        primary: false,
        requiredPermission: 'USER_MANAGE',
      ),
      (
        icon: Icons.file_download_outlined,
        label: 'Exportar datos',
        description: 'Descargar reportes',
        primary: false,
        requiredPermission: null,
      ),
    ];
    final actions = allActions.where(
      (action) =>
          action.requiredPermission == null ||
          permissions.contains(action.requiredPermission),
    );

    if (actions.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: columns == 2 ? 1.55 : 1.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final action in actions)
          Card(
            color: action.primary ? AppColors.primary : AppColors.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      action.icon,
                      color: action.primary ? Colors.white : AppColors.primary,
                      size: 30,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.label,
                          style: TextStyle(
                            color: action.primary
                                ? Colors.white
                                : AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action.description,
                          style: TextStyle(
                            color: action.primary
                                ? Colors.white70
                                : AppColors.slate,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
