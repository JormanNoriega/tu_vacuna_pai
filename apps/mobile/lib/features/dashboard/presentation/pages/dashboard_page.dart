import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/synchronization/sync_status_controller.dart';
import '../../../admin/presentation/admin_controller.dart';
import '../../../admin/presentation/pages/admin_page.dart';
import '../../../admin/presentation/pages/create_institution_admin_page.dart';
import '../../../admin/presentation/pages/create_institution_page.dart';
import '../../../admin/presentation/pages/super_admin_users_page.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/domain/entities/session_restore_result.dart';
import '../../../users/presentation/pages/users_page.dart';
import '../../../users/presentation/users_controller.dart';
import '../../../catalogs/presentation/catalog_controller.dart';
import '../../../catalogs/presentation/pages/catalog_page.dart';
import '../../../attentions/presentation/attention_controller.dart';
import '../../../attentions/presentation/history_controller.dart';
import '../../../attentions/presentation/pages/historial_page.dart';
import '../../../attentions/presentation/pages/nueva_atencion_page.dart';
import '../../../patients/presentation/patient_detail_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.user,
    required this.onSignOut,
    this.adminController,
    this.usersController,
    this.catalogController,
    this.attentionController,
    this.historyController,
    this.patientDetailController,
    this.sessionStatus = SessionStatus.signedIn,
    this.offlineReason,
    this.networkInfo,
    this.syncStatusController,
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

  /// Controlador del flujo clinico (nueva atencion e historial). Se inyecta
  /// desde [main]; es null en tests y demos.
  final AttentionController? attentionController;

  /// Controlador del historial de atenciones (estado independiente del flujo
  /// de nueva atencion).
  final HistoryController? historyController;

  /// Controlador de la ficha del paciente (ver + editar).
  final PatientDetailController? patientDetailController;

  /// Estado de la sesion restaurada. Define si se muestra un banner de modo
  /// offline y que operaciones de escritura estan permitidas.
  final SessionStatus sessionStatus;

  /// Razon de la ventana offline (noNetwork / backendUnavailable). Solo afecta
  /// la etiqueta del banner; la autorizacion vive en [sessionStatus].
  final OfflineReason? offlineReason;

  /// Conectividad del dispositivo para ajustar la etiqueta del banner en
  /// tiempo real. Null en tests (sin listener).
  final NetworkInfo? networkInfo;

  /// Proyeccion observable del estado de sincronizacion (outbox + ultimo
  /// resultado del engine). Null en tests y demos.
  final SyncStatusController? syncStatusController;

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
    unawaited(widget.syncStatusController?.refresh());
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
              isNewAttention: true,
            ),
            const _DashboardDestination(
              icon: Icons.history_rounded,
              selectedIcon: Icons.history_rounded,
              label: 'Historial',
              requiredPermission: 'ATTENTION_READ',
              isHistory: true,
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

  List<_DashboardDestination> get _superAdminDestinations => const [
    _DashboardDestination(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: 'Inicio',
    ),
    _DashboardDestination(
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance_rounded,
      label: 'Instituciones',
    ),
    _DashboardDestination(
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings_rounded,
      label: 'Usuarios',
    ),
    _DashboardDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Inventario',
    ),
  ];

  bool get _isSuperAdmin => widget.user.hasRole('SUPER_ADMIN');

  bool get _isSuperAdminView => _isSuperAdmin && widget.adminController != null;

  OfflineAccess get _offline => OfflineAccess(
    status: widget.sessionStatus,
    permissions: widget.user.permissions,
  );

  Widget _buildContent() {
    if (_isSuperAdminView) {
      return switch (_selectedIndex) {
        0 => _SuperAdminHome(
          userName: widget.user.name,
          controller: widget.adminController!,
          offline: _offline,
          onOpenCatalog: _openCatalog,
          onSelectTab: _selectTab,
        ),
        1 => AdminPage(controller: widget.adminController!, offline: _offline),
        2 => SuperAdminUsersPage(
          controller: widget.adminController!,
          offline: _offline,
        ),
        3 => _catalogContent(),
        _ => const SizedBox.shrink(),
      };
    }

    if (_destinations[_selectedIndex].isNewAttention &&
        widget.attentionController != null) {
      return NuevaAtencionPage(
        user: widget.user,
        controller: widget.attentionController!,
        offline: _offline,
      );
    }

    if (_destinations[_selectedIndex].isHistory &&
        widget.historyController != null &&
        widget.patientDetailController != null) {
      return HistorialPage(
        controller: widget.historyController!,
        patientDetailController: widget.patientDetailController!,
        offline: _offline,
      );
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
        embedded: true,
      );
    }

    return _DashboardContent(
      userName: widget.user.name,
      permissions: widget.user.permissions,
      onAction: _openQuickAction,
    );
  }

  /// Resuelve las acciones de "Acciones frecuentes" llevando al destino
  /// correspondiente del dashboard (o avisando si aun no existe).
  void _openQuickAction(String label) {
    final index = _destinations.indexWhere(
      (destination) => switch (label) {
        'Nueva atencion' => destination.isNewAttention,
        'Buscar paciente' => destination.isHistory,
        'Ver inventario' => destination.isCatalog,
        'Administracion' => destination.isUsersManagement,
        _ => false,
      },
    );
    if (index >= 0) {
      setState(() => _selectedIndex = index);
      return;
    }
    if (label == 'Exportar datos') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exportar datos: proximamente.')),
      );
    }
  }

  Widget _catalogContent() {
    final catalogController = widget.catalogController;
    if (catalogController == null) {
      return const Center(child: Text('Inventario no disponible.'));
    }
    return CatalogPage(
      user: widget.user,
      controller: catalogController,
      offline: _offline,
      embedded: true,
    );
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  void _openCatalog() {
    final catalogController = widget.catalogController;
    if (catalogController == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogPage(
          user: widget.user,
          controller: catalogController,
          offline: _offline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final destinations = _isSuperAdminView
        ? _superAdminDestinations
        : _destinations;
    final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1);
    final current = destinations[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .1),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(current.selectedIcon, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              current.label,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.syncStatusController != null)
            _SyncStatusBadge(controller: widget.syncStatusController!),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
      bottomNavigationBar: _LegacyNavBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: (value) => setState(() => _selectedIndex = value),
      ),
    );
  }
}

/// Insignia de sincronizacion en la barra superior: pendientes del outbox y
/// accion de forzar un ciclo. Se actualiza con [SyncStatusController].
class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({required this.controller});

  final SyncStatusController controller;

  String _tooltip(int pending, bool syncing) {
    if (syncing) return 'Sincronizando...';
    if (pending > 0) {
      return '$pending operacion(es) pendiente(s). Toca para sincronizar.';
    }
    return 'Todo sincronizado.';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pending = controller.pendingCount;
        final syncing = controller.syncing;
        final active = syncing || pending > 0;
        return IconButton(
          tooltip: _tooltip(pending, syncing),
          onPressed: syncing
              ? null
              : () async {
                  final outcome = await controller.syncNow();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        outcome.isSuccess
                            ? 'Sincronizacion completada.'
                            : 'No se pudo sincronizar: ${outcome.error}',
                      ),
                    ),
                  );
                },
          icon: Badge(
            isLabelVisible: pending > 0,
            label: Text('$pending'),
            child: Icon(
              syncing
                  ? Icons.cloud_sync_rounded
                  : active
                  ? Icons.cloud_upload_rounded
                  : Icons.cloud_done_rounded,
              color: active ? AppColors.primary : AppColors.slate,
            ),
          ),
        );
      },
    );
  }
}

/// Barra de navegacion inferior con el diseno de la app legacy: icono + etiqueta
/// por destino, item seleccionado en color primario, presente en todos los
/// tamanos de pantalla.
class _LegacyNavBar extends StatelessWidget {
  const _LegacyNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_DashboardDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 768;
    return Material(
      key: const Key('dashboard-nav-bar'),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .1),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.border.withValues(alpha: .5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: isTablet ? 70 : 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelected(i),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == selectedIndex
                                ? destinations[i].selectedIcon
                                : destinations[i].icon,
                            size: isTablet ? 30 : 26,
                            color: i == selectedIndex
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            destinations[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 10,
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: i == selectedIndex
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuperAdminHome extends StatefulWidget {
  const _SuperAdminHome({
    required this.userName,
    required this.controller,
    required this.offline,
    required this.onOpenCatalog,
    required this.onSelectTab,
  });

  final String userName;
  final AdminController controller;
  final OfflineAccess offline;
  final VoidCallback onOpenCatalog;
  final ValueChanged<int> onSelectTab;

  @override
  State<_SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends State<_SuperAdminHome> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadInstitutions();
  }

  Future<void> _openCreateInstitution() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateInstitutionPage(
          controller: widget.controller,
          offline: widget.offline,
        ),
      ),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Institucion "${created.name}" creada.')),
      );
    }
  }

  Future<void> _openCreateAdmin() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateInstitutionAdminPage(
          controller: widget.controller,
          offline: widget.offline,
        ),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario admin creado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 700 ? 32.0 : 16.0;
        final twoColumns = constraints.maxWidth >= 640;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SuperHero(userName: widget.userName),
                      const SizedBox(height: 24),
                      _SuperStats(
                        institutions: widget.controller.institutions.length,
                        admins: widget.controller.admins.length,
                        activeInstitutions: widget.controller.institutions
                            .where((institution) => institution.isActive)
                            .length,
                        twoColumns: twoColumns,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Acciones rapidas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _SuperActions(
                        onCreateInstitution: _openCreateInstitution,
                        onCreateAdmin: _openCreateAdmin,
                        onOpenCatalog: widget.onOpenCatalog,
                        onOpenUsers: () => widget.onSelectTab(2),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuperHero extends StatelessWidget {
  const _SuperHero({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final initials = userName.isEmpty
        ? '?'
        : userName
              .split(' ')
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF3E7BFA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: .2),
            foregroundColor: Colors.white,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${userName.split(' ').first}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Panel de control global del sistema',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .3)),
            ),
            child: const Text(
              'SUPER ADMIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuperStats extends StatelessWidget {
  const _SuperStats({
    required this.institutions,
    required this.admins,
    required this.activeInstitutions,
    required this.twoColumns,
  });

  final int institutions;
  final int admins;
  final int activeInstitutions;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        icon: Icons.account_balance_outlined,
        value: '$institutions',
        label: 'Instituciones',
        color: AppColors.primary,
      ),
      (
        icon: Icons.admin_panel_settings_outlined,
        value: '$admins',
        label: 'Administradores',
        color: AppColors.success,
      ),
      (
        icon: Icons.check_circle_outline,
        value: '$activeInstitutions',
        label: 'Activas',
        color: AppColors.warning,
      ),
    ];

    final children = [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];

    if (!twoColumns) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _SuperActions extends StatelessWidget {
  const _SuperActions({
    required this.onCreateInstitution,
    required this.onCreateAdmin,
    required this.onOpenCatalog,
    required this.onOpenUsers,
  });

  final VoidCallback onCreateInstitution;
  final VoidCallback onCreateAdmin;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenUsers;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.account_balance_rounded,
        label: 'Crear institucion',
        description: 'Registra una institucion de salud',
        primary: true,
        onTap: onCreateInstitution,
      ),
      (
        icon: Icons.admin_panel_settings_rounded,
        label: 'Crear admin',
        description: 'Admin de institucion',
        primary: false,
        onTap: onCreateAdmin,
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Ver inventario',
        description: 'Catalogo global de vacunas',
        primary: false,
        onTap: onOpenCatalog,
      ),
      (
        icon: Icons.people_alt_outlined,
        label: 'Gestionar usuarios',
        description: 'Administradores por institucion',
        primary: false,
        onTap: onOpenUsers,
      ),
    ];

    final children = [
      for (final action in actions)
        Card(
          color: action.primary ? AppColors.primary : AppColors.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: action.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    action.icon,
                    color: action.primary ? Colors.white : AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: action.primary ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
    ];

    // Grid responsivo con igual altura en todas las tarjetas: 4 columnas en
    // superficies amplias y 2 en movil/tablet, con proporcion adaptativa para
    // evitar desbordes del texto inferior.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 960 ? 4 : 2;
        final childAspectRatio = width >= 768
            ? 1.2
            : (width >= 600 ? 1.0 : 0.95);
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
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
    this.isNewAttention = false,
    this.isHistory = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? requiredPermission;
  final List<String> requiredPermissions;

  /// True cuando el destino corresponde a la gestion de usuarios de la
  /// institucion (ADMIN_INSTITUTION).
  final bool isUsersManagement;

  /// True cuando el destino es el flujo de una nueva atencion (VACCINATOR).
  final bool isNewAttention;

  /// True cuando el destino es el historial de atenciones del paciente.
  final bool isHistory;

  bool get isCatalog => label == 'Inventario';
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.userName,
    required this.permissions,
    required this.onAction,
  });

  final String userName;
  final List<String> permissions;
  final ValueChanged<String> onAction;

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
                    onAction: onAction,
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
  const _ActionsGrid({
    required this.columns,
    required this.permissions,
    required this.onAction,
  });

  final int columns;
  final List<String> permissions;
  final ValueChanged<String> onAction;

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
              onTap: () => onAction(action.label),
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
