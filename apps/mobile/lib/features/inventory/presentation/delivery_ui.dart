import 'package:flutter/material.dart';
import '../../../app/theme/app_theme.dart';

String deliveryStatus(Object? status) => switch (status) {
  'IN_TRANSIT' => 'Pendiente de recepción',
  'PARTIALLY_RECEIVED' => 'Diferencia pendiente',
  'RECEIVED' => 'Recibida',
  'CLOSED_WITH_DIFFERENCE' => 'Diferencia resuelta',
  _ => 'Estado por revisar',
};

String inventoryDate(Object? value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return 'Fecha no indicada';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String campaignDates(Map<String, dynamic> campaign) {
  final start = inventoryDate(campaign['startsOn']);
  return campaign['startsOn'] == campaign['endsOn']
      ? start
      : '$start – ${inventoryDate(campaign['endsOn'])}';
}

/// Estado vacío con estilo unificado y moderno de la aplicación.
class DeliveryEmptyState extends StatelessWidget {
  const DeliveryEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });
  final String title;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon ?? Icons.inventory_2_outlined,
            color: const Color(0xFF1E60EC),
            size: 26,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.slate,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
