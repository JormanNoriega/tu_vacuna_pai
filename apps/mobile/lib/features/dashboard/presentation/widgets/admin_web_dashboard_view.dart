import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/synchronization/sync_status_controller.dart';
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
class AdminWebDashboardView extends StatelessWidget {
  const AdminWebDashboardView({
    super.key,
    required this.userName,
    required this.institutionName,
    required this.institutionId,
    required this.onRefresh,
    this.metricsController,
    this.syncStatusController,
  });

  final String userName;
  final String institutionName;
  final String institutionId;
  final Future<void> Function() onRefresh;
  final MetricsController? metricsController;
  final SyncStatusController? syncStatusController;

  @override
  Widget build(BuildContext context) {
    final controllers = [
      ?metricsController,
      ?syncStatusController,
    ];
    final listenable = Listenable.merge(controllers);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
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
                          metricsController?.isLoading ?? false;
                      final patients =
                          metricsController?.summary.patientsAttended
                              .toString() ??
                          '0';
                      final doses =
                          metricsController?.summary.dosesApplied.toString() ??
                          '0';
                      final pendingSync =
                          syncStatusController?.pendingCount.toString() ?? '0';

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
                          metricsController?.summary.dosesApplied ?? 0;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isStacked = constraints.maxWidth < 1000;

                          if (isStacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AdminParametersCard(
                                  institutionName: institutionName,
                                  appliedDoses: appliedDosesCount,
                                ),
                                const SizedBox(height: 24),
                                AdminCoverageMapCard(
                                  institutionName: institutionName,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: AdminParametersCard(
                                  institutionName: institutionName,
                                  appliedDoses: appliedDosesCount,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: AdminCoverageMapCard(
                                  institutionName: institutionName,
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
                  'Bienvenido, $userName',
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
              'Panel de Control Clínico y Gestión Territorial · $institutionName',
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
                onPressed: onRefresh,
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
        label: 'Dosis Aplicadas Hoy',
        value: '28 Dosis',
        icon: Icons.today_rounded,
        color: AppColors.success,
        bgColor: AppColors.successSoft,
        subtext: 'Jornada activa en IPS',
      ),
      (
        label: 'Total Dosis PAI',
        value: doses,
        icon: Icons.vaccines_outlined,
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
        subtext: 'Histórico registrado en PAI',
      ),
      (
        label: 'Vacunadores Activos',
        value: '6 en Turno',
        icon: Icons.badge_outlined,
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFCCFBF1),
        subtext: 'Personal en sede y campo',
      ),
      (
        label: 'Alertas de Inventario',
        value: '2 en Riesgo',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        bgColor: AppColors.warningSoft,
        subtext: 'Biológicos con bajo saldo',
      ),
      (
        label: 'Pendientes Sincronización',
        value: pendingSync,
        icon: Icons.sync_rounded,
        color: const Color(0xFF64748B),
        bgColor: const Color(0xFFF1F5F9),
        subtext: 'Registros en outbox local',
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
