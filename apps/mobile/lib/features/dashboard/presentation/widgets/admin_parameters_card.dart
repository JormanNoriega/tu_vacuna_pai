import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';

/// Tarjeta de Parámetros Institucionales, Métricas y Monitoreo del PAI
/// para la vista de escritorio del Administrador.
class AdminParametersCard extends StatelessWidget {
  const AdminParametersCard({
    super.key,
    required this.institutionName,
    this.targetDoses = 500,
    this.appliedDoses = 0,
    this.todayDoses = 0,
    this.activeVaccinators = 0,
    this.isLoadingTodayDoses = false,
    this.isLoadingVaccinators = false,
  });

  final String institutionName;
  final int targetDoses;
  final int appliedDoses;
  final int todayDoses;
  final int activeVaccinators;
  final bool isLoadingTodayDoses;
  final bool isLoadingVaccinators;

  @override
  Widget build(BuildContext context) {
    final progress = (targetDoses > 0)
        ? (appliedDoses / targetDoses).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).toInt();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de la tarjeta
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parámetros y Métricas Operativas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        institutionName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Operativo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),

            // Módulo 1: Meta mensual de vacunación
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meta Mensual de Cobertura PAI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '$percentage% ($appliedDoses / $targetDoses dosis)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esquema regular de niños < 5 años y adultos mayores institucional.',
                    style: TextStyle(fontSize: 11, color: AppColors.slate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Módulo 2: Actividad Diaria y Personal Activo
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final todayItem = _buildParameterItem(
                  context: context,
                  icon: Icons.today_rounded,
                  iconColor: AppColors.primary,
                  bgColor: AppColors.primarySoft,
                  label: 'Dosis Aplicadas Hoy',
                  value: '$todayDoses dosis',
                  subtext: 'Jornada activa en IPS',
                  isLoading: isLoadingTodayDoses,
                );
                final vaccinatorsItem = _buildParameterItem(
                  context: context,
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF6366F1),
                  bgColor: const Color(0xFFEEF2FF),
                  label: 'Vacunadores Activos',
                  value: '$activeVaccinators en turno',
                  subtext: 'Personal habilitado en sede',
                  isLoading: isLoadingVaccinators,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      todayItem,
                      const SizedBox(height: 12),
                      vaccinatorsItem,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: todayItem),
                    const SizedBox(width: 14),
                    Expanded(child: vaccinatorsItem),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String subtext,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                isLoading
                    ? ShimmerEffect(
                        child: Container(
                          width: 48,
                          height: 16,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: const TextStyle(fontSize: 10, color: AppColors.hint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
