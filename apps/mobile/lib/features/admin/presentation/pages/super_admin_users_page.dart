import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../domain/entities/institution.dart';
import '../../domain/entities/institution_admin.dart';
import '../admin_controller.dart';
import 'create_institution_admin_page.dart';

/// Gestion de usuarios del SUPER_ADMIN: lista los administradores creados por
/// institucion y permite crear nuevos.
class SuperAdminUsersPage extends StatefulWidget {
  const SuperAdminUsersPage({
    required this.controller,
    required this.offline,
    super.key,
  });

  final AdminController controller;

  /// Estado de sesion actual: se propaga a las escrituras para aplicar la
  /// politica offline.
  final OfflineAccess offline;

  @override
  State<SuperAdminUsersPage> createState() => _SuperAdminUsersPageState();
}

class _SuperAdminUsersPageState extends State<SuperAdminUsersPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadAdmins();
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
      widget.controller.loadAdmins();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Usuarios',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Administradores de institucion registrados en el sistema.',
                    style: TextStyle(color: AppColors.slate, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: widget.controller.isLoading
                        ? null
                        : _openCreateAdmin,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Crear admin de institucion'),
                  ),
                  const SizedBox(height: 28),
                  if (widget.controller.error != null) ...[
                    _ErrorBanner(
                      message: widget.controller.error!,
                      onRetry: widget.controller.loadAdmins,
                      onDismiss: widget.controller.clearError,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.controller.adminsLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (widget.controller.institutions.isEmpty)
                    const _EmptyState(
                      icon: Icons.account_balance_outlined,
                      message:
                          'Crea una institucion para poder asignarle '
                          'administradores.',
                    )
                  else if (widget.controller.admins.isEmpty)
                    const _EmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      message: 'Todavia no hay administradores creados.',
                    )
                  else
                    for (final institution in widget.controller.institutions)
                      if (widget.controller.adminsFor(institution.id) > 0)
                        _AdminsByInstitution(
                          institution: institution,
                          admins: widget.controller.admins
                              .where(
                                (admin) =>
                                    admin.institutionId == institution.id,
                              )
                              .toList(),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminsByInstitution extends StatelessWidget {
  const _AdminsByInstitution({required this.institution, required this.admins});

  final Institution institution;
  final List<InstitutionAdmin> admins;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                institution.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _CountBadge(count: admins.length),
          ],
        ),
        const SizedBox(height: 10),
        for (final admin in admins) ...[
          _AdminTile(admin: admin, institutionName: institution.name),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({required this.admin, required this.institutionName});

  final InstitutionAdmin admin;
  final String institutionName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: .1),
          foregroundColor: AppColors.primary,
          child: Text(
            admin.fullName.isEmpty
                ? '?'
                : admin.fullName.substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(
          admin.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          admin.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Wrap(
          spacing: 6,
          children: [
            _RoleChip(roles: admin.roles),
            const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
          ],
        ),
        onTap: () => _showAdminDetails(context),
      ),
    );
  }

  void _showAdminDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(admin.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alternate_email_rounded),
              title: const Text('Correo'),
              subtitle: Text(admin.email),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Institucion'),
              subtitle: Text(institutionName),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Roles'),
              subtitle: Text(admin.roles.join(', ')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        roles.join(', '),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count admin${count == 1 ? '' : 's'}',
        style: const TextStyle(
          color: AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.hint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate),
          ),
        ],
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
