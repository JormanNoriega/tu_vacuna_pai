import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/vaccinator.dart';
import '../users_controller.dart';
import 'create_vaccinator_page.dart';

/// Gestion de usuarios de la institucion del ADMIN_INSTITUTION. Muestra los
/// vacunadores de la institucion y permite crear nuevos.
class UsersPage extends StatefulWidget {
  const UsersPage({
    required this.controller,
    required this.institutionId,
    super.key,
  });

  final UsersController controller;
  final String institutionId;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadUsers(institutionId: widget.institutionId);
  }

  Future<void> _openCreateVaccinator() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateVaccinatorPage(controller: widget.controller),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vacunador creado correctamente.')),
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
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gestion de usuarios',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea los vacunadores de tu institucion. Ellos podran '
                    'iniciar sesion y trabajar con o sin conexion.',
                    style: TextStyle(color: AppColors.slate, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (widget.controller.error != null) ...[
                    _ErrorBanner(
                      message: widget.controller.error!,
                      onRetry: () => widget.controller.loadUsers(
                        institutionId: widget.institutionId,
                      ),
                      onDismiss: widget.controller.clearError,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed: widget.controller.isLoading
                        ? null
                        : _openCreateVaccinator,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Crear vacunador'),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Vacunadores',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _UsersList(controller: widget.controller),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (controller.users.isEmpty) {
      return const Text(
        'Todavia no hay vacunadores en esta institucion.',
        style: TextStyle(color: AppColors.slate),
      );
    }

    return Column(
      children: [
        for (final user in controller.users) _UserTile(user: user),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final Vaccinator user;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: user.isActive
                ? AppColors.success.withValues(alpha: .12)
                : AppColors.hint.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: user.isActive ? AppColors.success : AppColors.hint,
            size: 20,
          ),
        ),
        title: Text(
          user.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _StatusChip(active: user.isActive),
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
        active ? 'ACTIVO' : 'INACTIVO',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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