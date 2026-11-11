import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/utils/field_input.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../inventory/presentation/inventory_controller.dart';
import '../catalog_controller.dart';
import '../../domain/entities/catalog_entities.dart';
import 'vaccine_form_page.dart';
import 'institution_vaccine_settings_page.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    required this.user,
    required this.controller,
    required this.offline,
    this.inventoryController,
    this.embedded = false,
    super.key,
  });

  /// Cuando [embedded] es true (p. ej. dentro del tab del dashboard) no se
  /// muestra AppBar propia, porque la barra del contenedor ya presenta el
  /// titulo. En rutas independientes (false) se muestra con su boton de volver.
  final bool embedded;
  final AuthUser user;
  final CatalogController controller;
  final OfflineAccess offline;
  final InventoryController? inventoryController;
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
      widget.controller.loadAvailable(widget.user.institution.id);
    } else if (globalAdmin) {
      widget.controller.load();
    } else {
      // VACCINATOR / READ_ONLY: catalogo efectivo de su institucion (las
      // vacunas habilitadas), en solo lectura.
      widget.controller.loadEffective();
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
    appBar: widget.embedded ? null : AppBar(title: const Text('Inventario')),
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
            if (institutionAdmin && c.hasAvailableVaccines) ...[
              _availableSection(c),
              const Divider(height: 1),
            ],
            if (c.error != null)
              _error(c)
            else
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: c.isLoading
                      ? ShimmerLoading(
                          key: const ValueKey('skeleton_view'),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            itemCount: 6,
                            itemBuilder: (context, index) => _skeletonCard(),
                          ),
                        )
                      : c.filteredVaccines.isEmpty
                      ? _empty(c)
                      : RefreshIndicator(
                          key: const ValueKey('real_list_view'),
                          onRefresh: () => institutionAdmin
                              ? c.loadInstitution(widget.user.institution.id)
                              : globalAdmin
                              ? c.load()
                              : c.loadEffective(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            itemCount: c.filteredVaccines.length,
                            itemBuilder: (_, i) => _card(c.filteredVaccines[i]),
                          ),
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
      inputFormatters: maxLengthFormatters(FieldLimits.vaccineName),
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
  Widget _availableSection(CatalogController c) => Container(
    width: double.infinity,
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.new_releases_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Vacunas disponibles',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Vacunas nuevas del catalogo global que aun no usas en tu '
          'institucion. Al habilitarlas se copia su configuracion por '
          'defecto sin tocar lo que ya configuraste.',
          style: TextStyle(color: AppColors.slate, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 8),
        for (final vaccine in c.availableVaccines)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: .1),
                foregroundColor: AppColors.primary,
                child: Text(
                  vaccine.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              title: Text(
                vaccine.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Codigo: ${vaccine.code}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: FilledButton.tonal(
                onPressed: c.isLoading ? null : () => _enableAvailable(vaccine),
                child: const Text('Habilitar'),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _enableAvailable(Vaccine vaccine) async {
    final ok = await widget.controller.enableAvailable(
      vaccine,
      widget.user.institution.id,
    );
    if (mounted && ok) {
      AppSnackbar.success(
        context,
        '"${vaccine.name}" habilitada en tu institucion. '
        'Puedes configurar sus opciones.',
      );
      widget.controller.loadInstitution(widget.user.institution.id);
    }
  }

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
  String _formatAgeRange(Vaccine v) {
    if (v.minAgeMonths == null && v.maxAgeMonths == null) {
      return 'Todas las edades';
    }
    if (v.minAgeMonths != null && v.maxAgeMonths != null) {
      return '${v.minAgeMonths}-${v.maxAgeMonths} meses';
    }
    if (v.minAgeMonths != null) {
      return 'Desde ${v.minAgeMonths} meses';
    }
    return 'Hasta ${v.maxAgeMonths} meses';
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePill({
    Widget? iconWidget,
    IconData? icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?iconWidget,
          if (icon != null)
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar Squircle simulado
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 14),
                // Líneas de Título, Subtítulo y Código
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 180,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
            // Chips simulados (Dosis, Edad, Categoría)
            Row(
              children: [
                _skeletonChip(width: 68),
                const SizedBox(width: 8),
                _skeletonChip(width: 110),
                const SizedBox(width: 8),
                _skeletonChip(width: 85),
              ],
            ),
            const SizedBox(height: 16),
            // Sección Características simulada
            Container(
              width: 90,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _skeletonPill(width: 60),
                const SizedBox(width: 8),
                _skeletonPill(width: 75),
                const SizedBox(width: 8),
                _skeletonPill(width: 65),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonChip({required double width}) => Container(
    width: width,
    height: 28,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
  );

  Widget _skeletonPill({required double width}) => Container(
    width: width,
    height: 28,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Widget _card(Vaccine v) {
    final canManage = globalAdmin || institutionAdmin;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canManage
              ? () => institutionAdmin ? _institutionSettings(v) : _options(v)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar Squircle + Título + Código
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0EDFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          v.name.isNotEmpty ? v.name[0].toUpperCase() : 'V',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          String mainName = v.name;
                          String? subName;

                          final parenMatch = RegExp(
                            r'^(.*?)\s*(\([^\)]+\))\s*$',
                          ).firstMatch(v.name);
                          if (parenMatch != null) {
                            mainName = parenMatch.group(1)!.trim();
                            subName = parenMatch.group(2)!.trim();
                          } else {
                            final lower = '${v.name} ${v.code} ${v.category}'
                                .toLowerCase();
                            if (lower.contains('suero')) {
                              subName = '(Suero)';
                            } else if (lower.contains('inmunoglobulina')) {
                              subName = '(Inmunoglobulina)';
                            } else if (lower.contains('antitoxina')) {
                              subName = '(Antitoxina)';
                            } else {
                              subName = '(Vacuna)';
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mainName,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subName,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Código: ${v.code}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: AppColors.slate),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 14),

                // Fila de Badges / Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaChip(
                      icon: Icons.format_list_numbered_rounded,
                      label: '${v.maxDoses} dosis',
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFF93C5FD),
                    ),
                    _metaChip(
                      icon: Icons.calendar_today_outlined,
                      label: _formatAgeRange(v),
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFF93C5FD),
                    ),
                    _metaChip(
                      icon: Icons.change_history_rounded,
                      label: v.category.toLowerCase().replaceAll(
                        'programa ampliado de inmunización (pai)',
                        'pai',
                      ),
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      borderColor: const Color(0xFFDDD6FE),
                    ),
                    if (!v.active)
                      _metaChip(
                        icon: Icons.visibility_off_outlined,
                        label: 'INACTIVA',
                        color: const Color(0xFFDC2626),
                        bgColor: const Color(0xFFFEF2F2),
                        borderColor: const Color(0xFFFECACA),
                      ),
                    if (institutionAdmin)
                      _metaChip(
                        icon:
                            (widget.controller.institutionEnabled[v.id] ??
                                false)
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        label:
                            (widget.controller.institutionEnabled[v.id] ??
                                false)
                            ? 'HABILITADA'
                            : 'DESHABILITADA',
                        color:
                            (widget.controller.institutionEnabled[v.id] ??
                                false)
                            ? AppColors.success
                            : AppColors.warning,
                        bgColor:
                            (widget.controller.institutionEnabled[v.id] ??
                                false)
                            ? AppColors.successSoft
                            : AppColors.warningSoft,
                        borderColor:
                            (widget.controller.institutionEnabled[v.id] ??
                                false)
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                  ],
                ),

                // Sección Características
                if (_hasFeature(v)) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Características:',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (v.hasLot)
                        _featurePill(
                          iconWidget: const Text(
                            '#',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          label: 'Lote',
                        ),
                      if (v.hasSyringe)
                        _featurePill(
                          icon: Icons.add_box_rounded,
                          label: 'Jeringa',
                        ),
                      if (v.hasSyringeLot)
                        _featurePill(
                          icon: Icons.grid_view_rounded,
                          label: 'Lote Jeringa',
                        ),
                      if (v.hasDiluent)
                        _featurePill(
                          icon: Icons.water_drop_rounded,
                          label: 'Diluyente',
                        ),
                      if (v.hasObservation)
                        _featurePill(
                          icon: Icons.folder_rounded,
                          label: 'Observaciones',
                        ),
                      if (v.hasVialCount)
                        _featurePill(
                          icon: Icons.numbers_rounded,
                          label: 'Cant. Frascos',
                        ),
                      if (v.hasLaboratory)
                        _featurePill(
                          icon: Icons.biotech_rounded,
                          label: 'Laboratorio',
                        ),
                      if (v.hasDropper)
                        _featurePill(
                          icon: Icons.opacity_rounded,
                          label: 'Gotero',
                        ),
                      if (v.hasPneumococcalType)
                        _featurePill(
                          icon: Icons.coronavirus_rounded,
                          label: 'Tipo Neumococo',
                        ),
                    ],
                  ),
                ],
                if (institutionAdmin) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _institutionSettings(v),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Configurar vacuna'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    key: const ValueKey('empty_view'),
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

  Future<void> _institutionSettings(Vaccine vaccine) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InstitutionVaccineSettingsPage(
          controller: widget.controller,
          vaccine: vaccine,
          institutionId: widget.user.institution.id,
          offline: widget.offline,
          canWrite: widget.user.hasPermission('CATALOG_CONFIG_WRITE'),
          inventoryController: widget.inventoryController,
        ),
      ),
    );
    if (!mounted) return;
    await widget.controller.loadInstitution(widget.user.institution.id);
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
      AppSnackbar.success(
        context,
        enabled ? 'Vacuna habilitada.' : 'Vacuna deshabilitada.',
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
              onPressed: () {
                Navigator.pop(context);
                _toggle(v);
              },
              child: Text(
                (widget.controller.institutionEnabled[v.id] ?? false)
                    ? 'Deshabilitar'
                    : 'Habilitar',
              ),
            ),
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
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _OptionDialog(
        title: 'Agregar opcion',
        autofocus: true,
        hint: 'Ej. Primera dosis, Pfizer, 0.5 ml',
        choices: [
          ('dose', 'Agregar como dosis'),
          if (globalAdmin) ('pneumococcalType', 'Tipo neumococo'),
          if (institutionAdmin) ...[
            ('laboratory', 'Laboratorio'),
            ('syringe', 'Jeringa'),
            ('dropper', 'Gotero'),
            ('observation', 'Observacion'),
          ],
        ],
      ),
    );
    if (!mounted || result == null || result.$2.isEmpty) return;
    final ok = await widget.controller.addOption(
      vaccine,
      optionPayload(fieldType: result.$1, value: result.$2, isDefault: false),
      institutionId: widget.user.institution.id,
      institutionScoped: institutionAdmin,
      offline: widget.offline,
    );
    if (mounted && !ok) {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudo agregar.',
      );
    }
  }

  Future<void> _editOption(Vaccine vaccine, VaccineOption option) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _OptionDialog(
        title: 'Editar opcion',
        initialValue: option.value,
        choices: const [('save', 'Guardar')],
      ),
    );
    if (!mounted || result == null || result.$2.isEmpty) return;
    await widget.controller.updateOption(
      vaccine,
      option,
      optionPayload(
        fieldType: option.fieldType,
        value: result.$2,
        isDefault: option.isDefault,
        sortOrder: option.sortOrder,
        version: option.version,
      ),
      institutionId: widget.user.institution.id,
      institutionScoped: institutionAdmin,
      offline: widget.offline,
    );
  }

  Future<void> _addTemplate(Vaccine vaccine) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _OptionDialog(
        title: 'Agregar plantilla operativa',
        autofocus: true,
        choices: [
          ('laboratory', 'laboratory'),
          ('syringe', 'syringe'),
          ('dropper', 'dropper'),
          ('observation', 'observation'),
        ],
      ),
    );
    if (!mounted || result == null || result.$2.isEmpty) return;
    await widget.controller.addTemplate(
      vaccine,
      optionPayload(fieldType: result.$1, value: result.$2, isDefault: false),
      offline: widget.offline,
    );
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

/// Dialogo con campo de texto que es dueño de su [TextEditingController]:
/// lo crea en [initState] y lo libera en [dispose], que corre cuando la ruta
/// del dialogo ya termino su animacion de salida. Esto evita el crash de
/// "TextEditingController used after being disposed" que ocurria al liberar el
/// controller justo despues de `await showDialog(...)`, mientras la vista
/// todavia se reconstruia durante el cierre del dialogo (p. ej. al ocultarse
/// el teclado).
class _OptionDialog extends StatefulWidget {
  const _OptionDialog({
    required this.title,
    this.autofocus = false,
    this.hint,
    this.initialValue,
    required this.choices,
  });

  final String title;
  final bool autofocus;
  final String? hint;
  final String? initialValue;

  /// Pares (valor devuelto, etiqueta del boton) de las acciones que confirman
  /// el valor ingresado. El primero se muestra como boton relleno.
  final List<(String, String)> choices;

  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    Navigator.pop(context, (value, _controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        inputFormatters: maxLengthFormatters(FieldLimits.optionValue),
        decoration: InputDecoration(
          labelText: 'Nombre o valor',
          hintText: widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        for (final (index, choice) in widget.choices.indexed)
          if (index == 0)
            FilledButton(
              onPressed: () => _submit(choice.$1),
              child: Text(choice.$2),
            )
          else
            TextButton(
              onPressed: () => _submit(choice.$1),
              child: Text(choice.$2),
            ),
      ],
    );
  }
}
