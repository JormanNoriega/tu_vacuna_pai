import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../domain/entities/vaccinator.dart';
import '../users_controller.dart';
import 'create_vaccinator_page.dart';

/// Gestion de usuarios de la institucion del ADMIN_INSTITUTION. Muestra los
/// vacunadores de la institucion y permite crear nuevos.
class UsersPage extends StatefulWidget {
  const UsersPage({
    required this.controller,
    required this.institutionId,
    required this.offline,
    super.key,
  });

  final UsersController controller;
  final String institutionId;

  /// Estado de sesion actual: se propaga a las escrituras para aplicar la
  /// politica offline.
  final OfflineAccess offline;

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
        builder: (_) => CreateVaccinatorPage(
          controller: widget.controller,
          offline: widget.offline,
        ),
      ),
    );
    if (created == true && mounted) {
      AppSnackbar.success(context, 'Vacunador creado correctamente.');
    }
  }

  Future<void> _openEditUser(Vaccinator user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(
        user: user,
        onSave: (status, roles) async {
          final ok = await widget.controller.updateUser(
            user,
            offline: widget.offline,
            status: status,
            roles: roles,
          );
          return ok
              ? null
              : (widget.controller.error ??
                    'No se pudo actualizar el usuario.');
        },
      ),
    );
    if (saved == true && mounted) {
      AppSnackbar.success(context, 'Usuario actualizado correctamente.');
    } else if (saved == false && mounted && widget.controller.error != null) {
      AppSnackbar.error(context, widget.controller.error!);
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
                  _UsersList(
                    controller: widget.controller,
                    onEditUser: _openEditUser,
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

class _UsersList extends StatelessWidget {
  const _UsersList({required this.controller, required this.onEditUser});

  final UsersController controller;
  final ValueChanged<Vaccinator> onEditUser;

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
        for (final user in controller.users)
          _UserTile(user: user, onTap: () => onEditUser(user)),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final Vaccinator user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
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
          _documentLabel(user),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(active: user.isActive),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Editar usuario',
              onPressed: onTap,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  /// Etiqueta del listado: documento (si existe) + correo.
  String _documentLabel(Vaccinator user) {
    final document = user.documentType == null || user.documentNumber == null
        ? ''
        : '${user.documentType} ${user.documentNumber}';
    if (document.isEmpty) return user.email;
    return '$document · ${user.email}';
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user, required this.onSave});

  final Vaccinator user;

  /// Devuelve null si la escritura se confirmo o un mensaje de error.
  final Future<String?> Function(String status, List<String> roles) onSave;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  static const _roleOptions = ['VACCINATOR', 'READ_ONLY'];

  late bool _active;
  late Set<String> _roles;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _active = widget.user.isActive;
    _roles = widget.user.roles.where(_roleOptions.contains).toSet();
  }

  Future<void> _save() async {
    if (_roles.isEmpty) {
      setState(() => _error = 'Selecciona al menos un rol.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(
      _active ? 'ACTIVE' : 'INACTIVE',
      _roles.toList(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  String _roleLabel(String code) => switch (code) {
    'VACCINATOR' => 'Vacunador',
    'READ_ONLY' => 'Solo lectura',
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar ${widget.user.fullName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Roles', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in _roleOptions)
                  FilterChip(
                    label: Text(_roleLabel(role)),
                    selected: _roles.contains(role),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _roles.add(role);
                            } else {
                              _roles.remove(role);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Usuario activo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _active
                    ? 'Puede iniciar sesion y trabajar.'
                    : 'Solo lectura bloqueada: no podra iniciar sesion.',
              ),
              value: _active,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _active = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
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
