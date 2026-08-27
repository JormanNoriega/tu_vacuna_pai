import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../catalog_controller.dart';
import '../../domain/entities/catalog_entities.dart';
import 'vaccine_form_page.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    required this.user,
    required this.controller,
    required this.offline,
    super.key,
  });
  final AuthUser user;
  final CatalogController controller;
  final OfflineAccess offline;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (institutionAdmin) {
      widget.controller.loadInstitution(widget.user.institution.id);
    } else {
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get globalAdmin => widget.user.hasRole('SUPER_ADMIN');
  bool get institutionAdmin => widget.user.hasRole('ADMIN_INSTITUTION');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Inventario'),
      actions: [
        IconButton(
          onPressed: () => institutionAdmin
              ? widget.controller.loadInstitution(widget.user.institution.id)
              : widget.controller.load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: globalAdmin
        ? FloatingActionButton.extended(
            onPressed: () => _form(),
            icon: const Icon(Icons.add),
            label: const Text('Nueva vacuna'),
          )
        : null,
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(
          children: [
            _search(c),
            _summary(c),
            if (c.error != null)
              _error(c)
            else
              Expanded(
                child: c.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : c.filteredVaccines.isEmpty
                    ? _empty(c)
                    : RefreshIndicator(
                        onRefresh: () => institutionAdmin
                            ? c.loadInstitution(widget.user.institution.id)
                            : c.load(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: c.filteredVaccines.length,
                          itemBuilder: (_, i) => _card(c.filteredVaccines[i]),
                        ),
                      ),
              ),
          ],
        );
      },
    ),
  );
  Widget _search(CatalogController c) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: TextField(
      controller: _searchController,
      onChanged: (v) {
        c.setQuery(v);
      },
      decoration: InputDecoration(
        hintText: 'Buscar vacuna por nombre o codigo...',
        prefixIcon: Icon(Icons.search),
        suffixIcon: c.query.isEmpty
            ? const Icon(Icons.tune_rounded)
            : IconButton(
                tooltip: 'Limpiar busqueda',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  c.setQuery('');
                },
              ),
      ),
    ),
  );
  Widget _summary(CatalogController c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    color: AppColors.surface,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.vaccines_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(
          '${c.filteredVaccines.length} vacunas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        Text(
          globalAdmin
              ? 'Catalogo global'
              : institutionAdmin
              ? 'Configuracion institucional'
              : 'Solo lectura',
          style: const TextStyle(color: AppColors.slate, fontSize: 12),
        ),
      ],
    ),
  );
  Widget _card(Vaccine v) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .1),
                foregroundColor: AppColors.primary,
                child: Text(v.name.substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Codigo: ${v.code}',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (globalAdmin || institutionAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit' && globalAdmin) _form(v);
                    if (value == 'toggle' && institutionAdmin) _toggle(v);
                  },
                  itemBuilder: (_) => [
                    if (globalAdmin)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar catalogo'),
                      ),
                    if (institutionAdmin)
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text('Cambiar disponibilidad'),
                      ),
                  ],
                ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('${v.maxDoses} dosis', Icons.format_list_numbered),
              _chip(v.ageRange, Icons.calendar_today),
              _chip(
                v.category.replaceAll(
                  'Programa Ampliado de Inmunización (PAI)',
                  'PAI',
                ),
                Icons.category,
                color: Colors.deepPurple,
              ),
              if (!v.active)
                _chip(
                  'INACTIVA',
                  Icons.visibility_off,
                  color: AppColors.warning,
                ),
              if (institutionAdmin)
                _chip(
                  (widget.controller.institutionEnabled[v.id] ?? false)
                      ? 'HABILITADA'
                      : 'DESHABILITADA',
                  (widget.controller.institutionEnabled[v.id] ?? false)
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  color: (widget.controller.institutionEnabled[v.id] ?? false)
                      ? AppColors.success
                      : AppColors.warning,
                ),
            ],
          ),
          if (_hasFeature(v)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (v.hasLaboratory) _featureChip('Laboratorio'),
                  if (v.hasLot) _featureChip('Lote'),
                  if (v.hasSyringe) _featureChip('Jeringa'),
                  if (v.hasSyringeLot) _featureChip('Lote jeringa'),
                  if (v.hasDiluent) _featureChip('Diluyente'),
                  if (v.hasDropper) _featureChip('Gotero'),
                  if (v.hasPneumococcalType) _featureChip('Tipo neumococo'),
                  if (v.hasVialCount) _featureChip('Conteo frascos'),
                  if (v.hasObservation) _featureChip('Observaciones'),
                ],
              ),
            ),
          ],
          if (globalAdmin || institutionAdmin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _options(v),
                icon: const Icon(Icons.tune),
                label: const Text('Opciones clinicas y operativas'),
              ),
            ),
        ],
      ),
    ),
  );
  Widget _chip(
    String label,
    IconData icon, {
    Color color = AppColors.primary,
  }) => Chip(
    avatar: Icon(icon, size: 16, color: color),
    label: Text(label),
    labelStyle: TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
  Widget _featureChip(String label) => Chip(
    label: Text(label),
    backgroundColor: AppColors.surface,
    side: const BorderSide(color: AppColors.border),
    labelStyle: const TextStyle(fontSize: 11),
  );
  bool _hasFeature(Vaccine v) =>
      v.hasLaboratory ||
      v.hasLot ||
      v.hasSyringe ||
      v.hasSyringeLot ||
      v.hasDiluent ||
      v.hasDropper ||
      v.hasPneumococcalType ||
      v.hasVialCount ||
      v.hasObservation;
  Widget _error(CatalogController c) => Expanded(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 44),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(c.error!, textAlign: TextAlign.center),
          ),
          FilledButton.icon(
            onPressed: c.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
  Widget _empty(CatalogController c) => Center(
    child: Text(
      c.query.isEmpty
          ? 'No hay vacunas en el catalogo.'
          : 'No se encontraron coincidencias.',
    ),
  );
  Future<void> _form([Vaccine? v]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaccineFormPage(
          controller: widget.controller,
          offline: widget.offline,
          vaccine: v,
        ),
      ),
    );
  }

  Future<void> _toggle(Vaccine v) async {
    final enabled = !(widget.controller.institutionEnabled[v.id] ?? false);
    final ok = await widget.controller.setEnabled(
      v,
      widget.user.institution.id,
      enabled,
      widget.offline,
    );
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Vacuna habilitada.' : 'Vacuna deshabilitada.',
          ),
        ),
      );
    }
  }

  Future<void> _options(Vaccine v) async {
    final token = await widget.controller.sessionManager.loadSession();
    if (!mounted || token == null) return;
    final options = await widget.controller.repository.listOptions(
      token.accessToken,
      v,
      institutionScoped: institutionAdmin,
      institutionId: widget.user.institution.id,
    );
    final templates = globalAdmin
        ? await widget.controller.repository.listTemplates(token.accessToken, v)
        : <VaccineOption>[];
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Opciones de ${v.name}'),
        content: SizedBox(
          width: 420,
          child: options.isEmpty && templates.isEmpty
              ? const Text('No hay opciones configuradas.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    if (templates.isNotEmpty)
                      const ListTile(
                        leading: Icon(Icons.auto_awesome),
                        title: Text('Plantillas operativas'),
                      ),
                    for (final o in [...templates, ...options])
                      ListTile(
                        title: Text(o.displayName),
                        subtitle: Text(o.fieldType),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (o.isDefault) const Text('Por defecto'),
                            if (!templates.contains(o) &&
                                _canManageType(o.fieldType))
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editOption(v, o),
                              ),
                            if (!templates.contains(o) &&
                                _canManageType(o.fieldType))
                              IconButton(
                                tooltip: 'Desactivar',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () => _disableOption(v, o),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          if (institutionAdmin)
            TextButton(
              onPressed: () async {
                await widget.controller.repository.importSuggestedOptions(
                  token.accessToken,
                  v,
                  widget.user.institution.id,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Importar sugeridas'),
            ),
          if (globalAdmin || institutionAdmin)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _addOption(v);
              },
              child: const Text('Agregar opcion'),
            ),
          if (globalAdmin)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _addTemplate(v);
              },
              child: const Text('Agregar plantilla'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOption(Vaccine vaccine) async {
    final value = TextEditingController();
    final fieldType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar opcion'),
        content: TextField(
          controller: value,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre o valor',
            hintText: 'Ej. Primera dosis, Pfizer, 0.5 ml',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'dose'),
            child: const Text('Agregar como dosis'),
          ),
          if (globalAdmin)
            TextButton(
              onPressed: () => Navigator.pop(context, 'pneumococcalType'),
              child: const Text('Tipo neumococo'),
            ),
          if (institutionAdmin) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'laboratory'),
              child: const Text('Laboratorio'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'syringe'),
              child: const Text('Jeringa'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'dropper'),
              child: const Text('Gotero'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'observation'),
              child: const Text('Observacion'),
            ),
          ],
        ],
      ),
    );
    if (!mounted || fieldType == null || value.text.trim().isEmpty) return;
    final ok = await widget.controller.addOption(
      vaccine,
      optionPayload(
        fieldType: fieldType,
        value: value.text.trim(),
        isDefault: false,
      ),
      institutionId: widget.user.institution.id,
      institutionScoped: institutionAdmin,
      offline: widget.offline,
    );
    value.dispose();
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.error ?? 'No se pudo agregar.'),
        ),
      );
    }
  }

  Future<void> _editOption(Vaccine vaccine, VaccineOption option) async {
    final value = TextEditingController(text: option.value);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar opcion'),
        content: TextField(
          controller: value,
          decoration: const InputDecoration(labelText: 'Nombre o valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true && value.text.trim().isNotEmpty && mounted) {
      await widget.controller.updateOption(
        vaccine,
        option,
        optionPayload(
          fieldType: option.fieldType,
          value: value.text.trim(),
          isDefault: option.isDefault,
          sortOrder: option.sortOrder,
          version: option.version,
        ),
        institutionId: widget.user.institution.id,
        institutionScoped: institutionAdmin,
        offline: widget.offline,
      );
    }
    value.dispose();
  }

  Future<void> _addTemplate(Vaccine vaccine) async {
    final value = TextEditingController();
    final fieldType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar plantilla operativa'),
        content: TextField(
          controller: value,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre o valor'),
        ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          for (final type in const [
            'laboratory',
            'syringe',
            'dropper',
            'observation',
          ])
            TextButton(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type),
            ),
        ],
      ),
    );
    if (fieldType != null && value.text.trim().isNotEmpty && mounted) {
      await widget.controller.addTemplate(
        vaccine,
        optionPayload(
          fieldType: fieldType,
          value: value.text.trim(),
          isDefault: false,
        ),
        offline: widget.offline,
      );
    }
    value.dispose();
  }

  Future<void> _disableOption(Vaccine vaccine, VaccineOption option) async {
    await widget.controller.disableOption(
      vaccine,
      option,
      institutionId: widget.user.institution.id,
      institutionScoped: institutionAdmin,
      offline: widget.offline,
    );
  }

  bool _canManageType(String type) => globalAdmin
      ? type == 'dose' || type == 'pneumococcalType'
      : type == 'laboratory' ||
            type == 'syringe' ||
            type == 'dropper' ||
            type == 'observation';
}
