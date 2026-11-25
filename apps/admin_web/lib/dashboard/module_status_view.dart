import 'package:flutter/material.dart';

import '../users/app_colors.dart';

class ModuleStatusView extends StatelessWidget {
  const ModuleStatusView({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.reason,
    required this.onSelect,
    this.availableSections = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String reason;
  final ValueChanged<String> onSelect;
  final List<(String, String, IconData)> availableSections;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(subtitle, style: const TextStyle(color: AppColors.slate)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 650;
                    final badge = Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 30),
                    );
                    final explanation = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'MÓDULO EN MIGRACIÓN',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reason,
                          style: const TextStyle(
                            color: AppColors.slate,
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                    return compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              badge,
                              const SizedBox(height: 18),
                              explanation,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              badge,
                              const SizedBox(width: 20),
                              Expanded(child: explanation),
                            ],
                          );
                  },
                ),
              ),
              if (availableSections.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Módulos disponibles ahora',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final section in availableSections)
                      _availableItem(section),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _availableItem((String, String, IconData) section) =>
      OutlinedButton.icon(
        onPressed: () => onSelect(section.$2),
        icon: Icon(section.$3),
        label: Text(section.$1),
      );
}
