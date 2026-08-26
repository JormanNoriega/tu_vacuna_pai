import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/institution.dart';
import '../admin_controller.dart';
import 'create_institution_admin_page.dart';
import 'create_institution_page.dart';

/// Seccion de administracion global del SUPER_ADMIN. Muestra exactamente dos
/// acciones: crear instituciones y crear administradores de institucion.
class AdminPage extends StatefulWidget {
  const AdminPage({required this.controller, super.key});

  final AdminController controller;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadInstitutions();
  }

  Future<void> _openCreateInstitution() async {
    final created = await Navigator.of(context).push<Institution>(
      MaterialPageRoute(
        builder: (_) => CreateInstitutionPage(controller: widget.controller),
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
        builder: (_) => CreateInstitutionAdminPage(controller: widget.controller),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Administracion',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Configura instituciones y crea los administradores que las gestionaran.',
                style: TextStyle(color: AppColors.slate, height: 1.4),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  if (widget.controller.error != null) {
                    return _ErrorBanner(
                      message: widget.controller.error!,
                      onRetry: widget.controller.loadInstitutions,
                      onDismiss: widget.controller.clearError,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 600;
                  final actions = [
                    _AdminActionCard(
                      icon: Icons.account_balance_rounded,
                      title: 'Crear institucion',
                      description: 'Registra una nueva institucion de salud.',
                      onTap: _openCreateInstitution,
                    ),
                    _AdminActionCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Crear usuario admin de institucion',
                      description:
                          'Crea el administrador que gestionara una institucion.',
                      onTap: _openCreateAdmin,
                    ),
                  ];

                  // Columnas reales (sin aspect ratio fijo) para que las
                  // tarjetas crezcan con su contenido y no haya overflow en
                  // pantallas angostas.
                  if (twoColumns) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: actions[i]),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        actions[i],
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _InstitutionsSection(controller: widget.controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warning.withValues(alpha: .1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
            IconButton(
              tooltip: 'Reintentar',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Descartar',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstitutionsSection extends StatelessWidget {
  const _InstitutionsSection({required this.controller});

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.institutions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.institutions.isEmpty) {
          return const Text(
            'Todavia no hay instituciones creadas.',
            style: TextStyle(color: AppColors.slate),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instituciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final institution in controller.institutions)
              _InstitutionTile(institution: institution),
          ],
        );
      },
    );
  }
}

class _InstitutionTile extends StatelessWidget {
  const _InstitutionTile({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: institution.isActive
                ? AppColors.success.withValues(alpha: .12)
                : AppColors.hint.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.account_balance_outlined,
            color: institution.isActive ? AppColors.success : AppColors.hint,
            size: 20,
          ),
        ),
        title: Text(
          institution.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${institution.code} - ventana offline ${institution.offlineWindowHours}h',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _StatusChip(active: institution.isActive),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.hint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'ACTIVA' : 'INACTIVA',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}