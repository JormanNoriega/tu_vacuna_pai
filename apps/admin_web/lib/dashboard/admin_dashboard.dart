import 'package:flutter/material.dart';

import '../connection/admin_session.dart';
import '../users/admin_web_users_view.dart';
import '../users/users_controller.dart';
import 'admin_web_sidebar.dart';
import 'home_view.dart';
import 'catalog_view.dart';
import 'statistics_view.dart';
import 'history_view.dart';
import 'delivery_view.dart';
import 'module_status_view.dart';

/// Navegación de la aplicación administrativa independiente.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({required this.session, super.key});
  final AdminSession session;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<List<Map<String, dynamic>>>? _catalog;
  Future<List<Map<String, dynamic>>>? _stock;
  late final UsersController _users;
  String _section = 'inicio';
  String _historyTab = 'registro';
  Future<Map<String, dynamic>>? _metrics;

  @override
  void initState() {
    super.initState();
    _users = UsersController(widget.session);
    _metrics = widget.session.loadMetrics();
  }

  @override
  void dispose() {
    _users.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _catalog = widget.session.canReadCatalog
        ? widget.session.loadCatalog()
        : null;
    _stock = widget.session.canReadInventory
        ? widget.session.loadInventoryList('lots')
        : null;
  });

  void _selectSection(String section) {
    setState(() => _section = section);
    if (section == 'inventario' &&
        (widget.session.canReadCatalog || widget.session.canReadInventory) &&
        _catalog == null) {
      _reload();
    }
    if (section == 'administracion' && widget.session.canReadUsers) {
      _users.loadUsers(institutionId: widget.session.institutionId!);
    }
  }

  void _selectAction(String action) {
    if (action == 'Administracion') {
      _selectSection('administracion');
    } else if (action == 'Inventario') {
      _selectSection('inventario');
    } else if (action.contains('Historial')) {
      _historyTab = 'registro';
      _selectSection('historial');
    } else if (action.contains('Exportar')) {
      _historyTab = 'reportes';
      _selectSection('historial');
    } else if (action.contains('Expediente')) {
      _historyTab = 'expediente';
      _selectSection('historial');
    } else if (action.contains('Estadisticas')) {
      _selectSection('estadisticas');
    } else if (action.contains('Vacunas') || action.contains('Ajustes')) {
      _selectSection('inventario_pendiente');
    } else if (action == 'Jornadas') {
      _selectSection('jornadas');
    } else if (action == 'Custodia y cierre') {
      _selectSection('custodia');
    } else if (action == 'Conciliacion') {
      _selectSection('conciliacion_pendiente');
    } else {
      _selectSection('entregas');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      body: Row(
        children: [
          AdminWebSidebar(
            selectedSection: _section,
            onSelectSection: _selectSection,
            onAction: _selectAction,
            onSignOut: () => session.signOut(),
            userName: session.name ?? '',
            institutionName: session.institutionName ?? 'Institución',
            isSuperAdmin: session.isSuperAdmin,
          ),
          Expanded(
            child: switch (_section) {
              'inicio' => HomeView(
                name: session.name ?? '',
                institutionName: session.institutionName ?? 'Institución',
                metrics: _metrics!,
                onNavigate: _selectSection,
                onRefresh: () => setState(() {
                  _metrics = session.loadMetrics();
                }),
              ),
              'administracion' when session.canReadUsers => AdminWebUsersView(
                controller: _users,
                institutionId: session.institutionId!,
                institutionName: session.institutionName ?? 'Institución',
              ),
              'inventario' => CatalogView(
                catalog: _catalog,
                stock: _stock,
                global: session.globalCatalog,
                institutionName: session.institutionName ?? 'institución',
                onRefresh: _reload,
              ),
              'estadisticas' => StatisticsView(
                institutionName: session.institutionName ?? 'Institución',
                metrics: _metrics!,
                onRefresh: () => setState(() {
                  _metrics = session.loadMetrics();
                }),
              ),
              'historial' => HistoryView(
                session: session,
                initialTab: _historyTab,
              ),
              'entregas' || 'jornadas' || 'custodia' => DeliveryView(
                session: session,
                section: _section,
                onSelect: _selectSection,
              ),
              _ => _moduleStatus(session),
            },
          ),
        ],
      ),
    );
  }

  Widget _moduleStatus(AdminSession session) {
    final (title, subtitle, icon, reason) = switch (_section) {
      'instituciones' => (
        'Instituciones',
        'Administración global de sedes y configuración',
        Icons.account_balance_outlined,
        'La interfaz original incluye gestión de instituciones. La consulta y edición aún no se han conectado en esta aplicación web.',
      ),
      'exportacion_pendiente' => (
        'Exportación de reportes PAI',
        'Descarga de información clínica institucional',
        Icons.download_outlined,
        'La exportación requiere un contrato de descarga con permisos y alcance institucional. No se genera ningún archivo hasta conectar y validar ese flujo.',
      ),
      'inventario_pendiente' => (
        'Configuración y ajustes de inventario',
        'Parámetros de biológicos y regularización de existencias',
        Icons.tune_outlined,
        'El catálogo de lectura está disponible. La configuración de vacunas, lotes y ajustes requiere endpoints de escritura y validación; no se permiten cambios desde esta pantalla.',
      ),
      'conciliacion_pendiente' => (
        'Conciliación de diferencias',
        'Cierre y revisión de entregas de biológicos',
        Icons.fact_check_outlined,
        'Se consultan entregas y eventos de custodia cuando la API de inventario está habilitada. La conciliación y el cierre aún no se conectan.',
      ),
      'administracion' => (
        'Administración de personal',
        'Usuarios y vacunadores institucionales',
        Icons.people_outline,
        'Tu perfil no tiene permisos para consultar el personal de esta institución.',
      ),
      _ => (
        'Módulo no disponible',
        'Esta sección está en proceso de migración',
        Icons.construction_outlined,
        'La interfaz y su conexión con los servicios aún están en desarrollo.',
      ),
    };

    return ModuleStatusView(
      title: title,
      subtitle: subtitle,
      icon: icon,
      reason: reason,
      onSelect: _selectSection,
      availableSections: [
        if (session.canReadUsers)
          ('Personal', 'administracion', Icons.people_outline),
        if (session.canReadCatalog)
          ('Catálogo', 'inventario', Icons.vaccines_outlined),
        if (session.canReadHistory) ('Historial', 'historial', Icons.history),
        if (session.canReadInventory)
          ('Entregas y custodia', 'entregas', Icons.local_shipping_outlined),
        ('Inicio', 'inicio', Icons.space_dashboard_outlined),
      ],
    );
  }
}
