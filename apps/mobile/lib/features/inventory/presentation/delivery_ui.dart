import 'package:flutter/material.dart';

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

/// Estado vacío sin cifras sintéticas ni acciones decorativas.
class DeliveryEmptyState extends StatelessWidget {
  const DeliveryEmptyState({
    super.key,
    required this.title,
    required this.message,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message),
      ],
    ),
  );
}
