import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/synchronization/sync_status_controller.dart';
import '../../../attentions/presentation/history_controller.dart';
import '../../../reports/presentation/export_report_controller.dart';
import '../../../users/presentation/users_controller.dart';
import '../metrics_controller.dart';
import 'admin_coverage_map_card.dart';
import 'admin_parameters_card.dart';

/// Vista de inicio (Dashboard de bienvenida) adaptada para PC (Web/Desktop)
/// para usuarios Administradores.
///
/// Muestra de entrada:
/// 1. Cabecera con datos de la institución, fecha y estado de sincronización.
/// 2. Fila superior de 4 tarjetas de estadísticas clave (KPIs).
/// 3. Bloque central dividido en Parámetros Operativos del PAI y Espacio del Mapa.
class AdminWebDashboardView extends StatefulWidget {
  const AdminWebDashboardView({
    super.key,
    required this.userName,
    required this.institutionName,
    required this.institutionId,
    required this.onRefresh,
    this.metricsController,
    this.syncStatusController,
    this.usersController,
    this.historyController,
    this.exportReportController,
  });

  final String userName;
  final String institutionName;
  final String institutionId;
  final Future<void> Function() onRefresh;
  final MetricsController? metricsController;
  final SyncStatusController? syncStatusController;
  final UsersController? usersController;
  final HistoryController? historyController;
  final ExportReportController? exportReportController;

  @override
  State<AdminWebDashboardView> createState() => _AdminWebDashboardViewState();
}

class _AdminWebDashboardViewState extends State<AdminWebDashboardView> {
  int _todayDoses = 0;
  bool _isLoadingTodayDoses = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant AdminWebDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.institutionId != widget.institutionId) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    if (widget.usersController != null && widget.usersController!.users.isEmpty) {
      widget.usersController!.loadUsers(institutionId: widget.institutionId);
    }
    await _fetchTodayDoses();
  }

  Future<void> _fetchTodayDoses() async {
    if (!mounted) return;
    setState(() => _isLoadingTodayDoses = true);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    int count = 0;
    try {
      if (widget.exportReportController != null) {
        final session = await widget.exportReportController!.sessionManager.loadSession();
        final token = session?.accessToken;
        if (token != null) {
          final summary = await widget.exportReportController!.repository.fetchSummary(
            token,
            from: startOfDay,
            to: endOfDay,
            institutionId: widget.institutionId,
          );
          count = summary.dosesCount;
        }
      } else if (widget.historyController != null) {
        final pageResult = await widget.historyController!.recentPage(
          admin: true,
          institutionId: widget.institutionId,
          userId: '',
          from: startOfDay,
          to: endOfDay,
          page: 0,
          offline: false,
        );
        for (final item in (pageResult['items'] as List? ?? [])) {
          final doses = item['doses'] as List? ?? [];
          count += doses.length;
        }
      }
    } catch (_) {
      count = 0;
    } finally {
      if (mounted) {
        setState(() {
          _todayDoses = count;
          _isLoadingTodayDoses = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      widget.onRefresh(),
      if (widget.usersController != null)
        widget.usersController!.loadUsers(institutionId: widget.institutionId),
      _fetchTodayDoses(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final controllers = [
      if (widget.metricsController != null) widget.metricsController!,
      if (widget.syncStatusController != null) widget.syncStatusController!,
      if (widget.usersController != null) widget.usersController!,
    ];
    final listenable = Listenable.merge(controllers);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Cabecera administrativa de escritorio
                  _buildDesktopHeader(context),
                  const SizedBox(height: 24),

                  // 2. Fila de 4 KPIs / Estadísticas principales
                  AnimatedBuilder(
                    animation: listenable,
                    builder: (context, _) {
                      final isMetricsLoading =
                          widget.metricsController?.isLoading ?? false;
                      final patients =
                          widget.metricsController?.summary.patientsAttended
                              .toString() ??
                          '0';
                      final doses =
                          widget.metricsController?.summary.dosesApplied.toString() ??
                          '0';
                      final pendingSync =
                          widget.syncStatusController?.pendingCount.toString() ?? '0';

                      return _buildKpiRow(
                        context: context,
                        patients: patients,
                        doses: doses,
                        pendingSync: pendingSync,
                        isLoading: isMetricsLoading,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. Bloque Central Panorámico: Parámetros (Izquierda) + Mapa (Derecha)
                  AnimatedBuilder(
                    animation: listenable,
                    builder: (context, _) {
                      final appliedDosesCount =
                          widget.metricsController?.summary.dosesApplied ?? 0;

                      final users = widget.usersController?.users ?? const [];
                      final activeVaccinators = users.isNotEmpty
                          ? users.where((u) => u.isActive).length
                          : 0;
                      final isUsersLoading =
                          widget.usersController?.isLoading ?? false;

                      final parametersCard = AdminParametersCard(
                        institutionName: widget.institutionName,
                        appliedDoses: appliedDosesCount,
                        todayDoses: _todayDoses,
                        activeVaccinators: activeVaccinators,
                        isLoadingTodayDoses: _isLoadingTodayDoses,
                        isLoadingVaccinators: isUsersLoading && users.isEmpty,
                      );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isStacked = constraints.maxWidth < 1000;

                          if (isStacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                parametersCard,
                                const SizedBox(height: 24),
                                AdminCoverageMapCard(
                                  institutionName: widget.institutionName,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: parametersCard,
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: AdminCoverageMapCard(
                                  institutionName: widget.institutionName,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;

        final userDetails = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  'Bienvenido, ${widget.userName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ADMINISTRADOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Panel de Control Clínico y Gestión Territorial · ${widget.institutionName}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final headerActions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Actualizar métricas',
              child: IconButton.filledTonal(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceAlt,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: _handleRefresh,
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    userDetails,
                    const SizedBox(height: 14),
                    headerActions,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: userDetails),
                    const SizedBox(width: 16),
                    headerActions,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildKpiRow({
    required BuildContext context,
    required String patients,
    required String doses,
    required String pendingSync,
    required bool isLoading,
  }) {
    final kpis = [
      (
        label: 'Pacientes Atendidos',
        value: patients,
        icon: Icons.people_alt_outlined,
        color: AppColors.primary,
        bgColor: AppColors.primarySoft,
        subtext: 'Población acumulada en IPS',
      ),
      (
        label: 'Total Dosis PAI',
        value: doses,
        icon: Icons.vaccines_outlined,
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
        subtext: 'Histórico registrado en servidor',
      ),
      (
        label: 'Estado del Servicio',
        value: 'En Línea',
        icon: Icons.cloud_done_rounded,
        color: AppColors.success,
        bgColor: AppColors.successSoft,
        subtext: 'Conexión activa al backend',
      ),
      (
        label: 'Sede Institucional',
        value: widget.institutionName.isNotEmpty ? widget.institutionName : 'IPS Activa',
        icon: Icons.domain_rounded,
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFCCFBF1),
        subtext: 'Entorno de gestión central',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 650 ? 2 : 1);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final kpi in kpis)
              SizedBox(
                width: (constraints.maxWidth - ((columns - 1) * 16)) / columns,
                child: _buildKpiCard(context, kpi, isLoading: isLoading),
              ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    ({
      Color bgColor,
      Color color,
      IconData icon,
      String label,
      String subtext,
      String value,
    })
    kpi, {
    required bool isLoading,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kpi.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(kpi.icon, color: kpi.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  isLoading
                      ? ShimmerEffect(
                          child: Container(
                            width: 50,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        )
                      : Text(
                          kpi.value,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                  const SizedBox(height: 2),
                  Text(
                    kpi.subtext,
                    style: const TextStyle(fontSize: 10, color: AppColors.hint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
