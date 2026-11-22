import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Tarjeta de Parámetros Institucionales, Métricas y Monitoreo del PAI
/// para la vista de escritorio del Administrador.
class AdminParametersCard extends StatelessWidget {
  const AdminParametersCard({
    super.key,
    required this.institutionName,
    this.coldChainTemp = 4.2,
    this.paiwebOnline = true,
    this.targetDoses = 500,
    this.appliedDoses = 342,
    this.activeVaccinators = 6,
  });

  final String institutionName;
  final double coldChainTemp;
  final bool paiwebOnline;
  final int targetDoses;
  final int appliedDoses;
  final int activeVaccinators;

  @override
  Widget build(BuildContext context) {
    final progress = (targetDoses > 0)
        ? (appliedDoses / targetDoses).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).toInt();

    final isTempSafe = coldChainTemp >= 2.0 && coldChainTemp <= 8.0;

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

            // Módulo 1: Cadena de Frío y PAIWEB
            Row(
              children: [
                Expanded(
                  child: _buildParameterItem(
                    context: context,
                    icon: Icons.ac_unit_rounded,
                    iconColor: isTempSafe
                        ? const Color(0xFF0284C7)
                        : AppColors.danger,
                    bgColor: isTempSafe
                        ? const Color(0xFFE0F2FE)
                        : AppColors.dangerSoft,
                    label: 'Red de Frío',
                    value: '${coldChainTemp.toStringAsFixed(1)} °C',
                    subtext: isTempSafe
                        ? 'Rango Seguro (+2° a +8°C)'
                        : 'Alerta de Temperatura',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildParameterItem(
                    context: context,
                    icon: Icons.cloud_sync_rounded,
                    iconColor: paiwebOnline
                        ? AppColors.success
                        : AppColors.warning,
                    bgColor: paiwebOnline
                        ? AppColors.successSoft
                        : AppColors.warningSoft,
                    label: 'Servicio PAIWEB',
                    value: paiwebOnline ? 'En línea' : 'Sin conexión',
                    subtext: 'Sincronización directa',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Módulo 2: Meta mensual de vacunación
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

            // Módulo 3: Parámetros del personal y alertas
            Row(
              children: [
                Expanded(
                  child: _buildParameterItem(
                    context: context,
                    icon: Icons.badge_outlined,
                    iconColor: AppColors.primary,
                    bgColor: AppColors.primarySoft,
                    label: 'Vacunadores en Campo',
                    value: '$activeVaccinators activos',
                    subtext: 'Jornadas institucionales',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildParameterItem(
                    context: context,
                    icon: Icons.health_and_safety_outlined,
                    iconColor: AppColors.success,
                    bgColor: AppColors.successSoft,
                    label: 'Bioseguridad & Stock',
                    value: '100% Óptimo',
                    subtext: 'Sin lotes en riesgo',
                  ),
                ),
              ],
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
                Text(
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
