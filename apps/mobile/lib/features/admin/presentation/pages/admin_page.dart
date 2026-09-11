import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../domain/entities/clone_catalog_result.dart';
import '../../domain/entities/institution.dart';
import '../admin_controller.dart';
import 'create_institution_page.dart';

/// Seccion de administracion global del SUPER_ADMIN. Muestra las instituciones
/// registradas y permite crear nuevas. La gestion de administradores vive en
/// el panel de Usuarios.
class AdminPage extends StatefulWidget {
  const AdminPage({required this.controller, required this.offline, super.key});

  final AdminController controller;

  /// Estado de sesion actual: se propaga a las escrituras para aplicar la
  /// politica offline.
  final OfflineAccess offline;

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
        builder: (_) => CreateInstitutionPage(
          controller: widget.controller,
          offline: widget.offline,
        ),
      ),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Institucion "${created.name}" creada.')),
      );
    }
  }

  Future<void> _openEditConfig(Institution institution) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditConfigDialog(
        institution: institution,
        onSave: (offlineWindowHours) async {
          final ok = await widget.controller.updateInstitutionConfig(
            institution,
            offline: widget.offline,
            offlineWindowHours: offlineWindowHours,
          );
          return ok
              ? null
              : (widget.controller.error ??
                    'No se pudo actualizar la configuracion.');
        },
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ventana offline de "${institution.name}" actualizada.',
          ),
        ),
      );
    }
  }

  Future<void> _openCloneCatalog(Institution institution) async {
    final result = await showDialog<CloneCatalogResult>(
      context: context,
      builder: (_) => _CloneCatalogDialog(
        institution: institution,
        onClone: (includeDefaultConfig) async {
          final cloned = await widget.controller.cloneCatalogToInstitution(
            institution,
            offline: widget.offline,
            includeDefaultConfig: includeDefaultConfig,
          );
          if (cloned == null) {
            throw _CloneException(
              widget.controller.error ?? 'No se pudo clonar el catalogo.',
            );
          }
          return cloned;
        },
      ),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Catalogo clonado en "${institution.name}": '
          '${result.vaccinesEnabled} vacunas habilitadas '
          '(${result.optionsCopied} opciones copiadas).',
        ),
      ),
    );
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
                'Instituciones',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Registra instituciones de salud y administra su configuracion.',
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
              _AdminActionCard(
                icon: Icons.account_balance_rounded,
                title: 'Crear institucion',
                description:
                    'Registra una nueva institucion de salud. Despues podras '
                    'asignarle su administrador desde el panel de Usuarios.',
                onTap: _openCreateInstitution,
              ),
              const SizedBox(height: 28),
              _InstitutionsSection(
                controller: widget.controller,
                onEditConfig: _openEditConfig,
                onCloneCatalog: _openCloneCatalog,
              ),
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
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppColors.primary, size: 34),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstitutionsSection extends StatelessWidget {
  const _InstitutionsSection({
    required this.controller,
    required this.onEditConfig,
    required this.onCloneCatalog,
  });

  final AdminController controller;
  final ValueChanged<Institution> onEditConfig;
  final ValueChanged<Institution> onCloneCatalog;

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
              _InstitutionTile(
                institution: institution,
                adminCount: controller.adminsFor(institution.id),
                onEditConfig: () => onEditConfig(institution),
                onCloneCatalog: () => onCloneCatalog(institution),
              ),
          ],
        );
      },
    );
  }
}

class _InstitutionTile extends StatelessWidget {
  const _InstitutionTile({
    required this.institution,
    required this.adminCount,
    required this.onEditConfig,
    required this.onCloneCatalog,
  });

  final Institution institution;
  final int adminCount;
  final VoidCallback onEditConfig;
  final VoidCallback onCloneCatalog;

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CountBadge(adminCount: adminCount),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clonar catalogo',
              onPressed: onCloneCatalog,
              icon: const Icon(Icons.content_copy_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Editar configuracion',
              onPressed: onEditConfig,
              icon: const Icon(Icons.settings_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.adminCount});

  final int adminCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$adminCount admin${adminCount == 1 ? '' : 's'}',
        style: const TextStyle(
          color: AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Error del clonado: se muestra dentro del dialogo sin cerrarlo.
class _CloneException implements Exception {
  const _CloneException(this.message);

  final String message;
}

class _CloneCatalogDialog extends StatefulWidget {
  const _CloneCatalogDialog({required this.institution, required this.onClone});

  final Institution institution;

  /// Devuelve el resumen del clonado o lanza [_CloneException] si falla.
  final Future<CloneCatalogResult> Function(bool includeDefaultConfig) onClone;

  @override
  State<_CloneCatalogDialog> createState() => _CloneCatalogDialogState();
}

class _CloneCatalogDialogState extends State<_CloneCatalogDialog> {
  bool _includeDefaultConfig = true;
  bool _cloning = false;
  String? _error;

  Future<void> _clone() async {
    setState(() {
      _cloning = true;
      _error = null;
    });
    try {
      final result = await widget.onClone(_includeDefaultConfig);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on _CloneException catch (error) {
      if (!mounted) return;
      setState(() {
        _cloning = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clonar catalogo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habilita todo el catalogo global en '
            '"${widget.institution.name}".',
            style: const TextStyle(color: AppColors.slate, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Agregar la configuracion por defecto?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: _cloning,
            child: RadioGroup<bool>(
              groupValue: _includeDefaultConfig,
              onChanged: (value) =>
                  setState(() => _includeDefaultConfig = value ?? true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: const Text('Si, con configuracion por defecto'),
                    subtitle: const Text(
                      'Copia laboratorio, jeringa, gotero y observacion '
                      'de cada vacuna.',
                    ),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: const Text('No, solo habilitar las vacunas'),
                    subtitle: const Text(
                      'Las opciones se configuran despues por la institucion.',
                    ),
                  ),
                ],
              ),
            ),
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
      actions: [
        TextButton(
          onPressed: _cloning ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _cloning ? null : _clone,
          child: _cloning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Clonar'),
        ),
      ],
    );
  }
}

class _EditConfigDialog extends StatefulWidget {
  const _EditConfigDialog({required this.institution, required this.onSave});

  final Institution institution;

  /// Devuelve null si la escritura se confirmo o un mensaje de error.
  final Future<String?> Function(int offlineWindowHours) onSave;

  @override
  State<_EditConfigDialog> createState() => _EditConfigDialogState();
}

class _EditConfigDialogState extends State<_EditConfigDialog> {
  late final TextEditingController _hoursController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(
      text: '${widget.institution.offlineWindowHours}',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hours = int.tryParse(_hoursController.text.trim());
    if (hours == null || hours < 1 || hours > 168) {
      setState(() => _error = 'Usa un valor entre 1 y 168 horas.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(hours);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configurar ${widget.institution.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventana offline (horas)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hoursController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '72',
              helperText: 'Entre 1 y 168 horas. Rige el trabajo sin conexion.',
              prefixIcon: Icon(Icons.cloud_off_outlined),
            ),
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
