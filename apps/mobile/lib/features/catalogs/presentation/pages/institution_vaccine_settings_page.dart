import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../inventory/presentation/inventory_controller.dart';
import '../../../inventory/presentation/stock_entry_page.dart';
import '../../../auth/domain/entities/session_restore_result.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/effective_catalog.dart';
import '../catalog_controller.dart';

/// Configuración operativa de una vacuna en una institución concreta.
class InstitutionVaccineSettingsPage extends StatefulWidget {
  const InstitutionVaccineSettingsPage({
    super.key,
    required this.controller,
    required this.vaccine,
    required this.institutionId,
    required this.offline,
    required this.canWrite,
    this.inventoryController,
  });

  final CatalogController controller;
  final Vaccine vaccine;
  final String institutionId;
  final OfflineAccess offline;
  final bool canWrite;
  final InventoryController? inventoryController;

  @override
  State<InstitutionVaccineSettingsPage> createState() =>
      _InstitutionVaccineSettingsPageState();
}

class _InstitutionVaccineSettingsPageState
    extends State<InstitutionVaccineSettingsPage> {
  List<VaccineOption> _options = const [];
  List<EffectiveOption>? _doses;
  String? _dosesError;
  bool _loadingOptions = true;
  bool _loadingStock = false;
  String? _error;

  Vaccine get vaccine => widget.vaccine;
  bool get enabled => widget.controller.institutionEnabled[vaccine.id] ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() async =>
      (await widget.controller.sessionManager.loadSession())?.accessToken;

  Future<void> _load() async {
    setState(() {
      _loadingOptions = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        throw StateError(
          'La sesión expiró. Inicia sesión e inténtalo de nuevo.',
        );
      }
      final options = await widget.controller.repository.listOptions(
        token,
        vaccine,
        institutionScoped: true,
        institutionId: widget.institutionId,
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _loadingOptions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loadingOptions = false;
      });
    }
    await _loadStock();
    await _loadDoses();
  }

  Future<void> _loadDoses() async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) throw StateError('Sin sesión');
      final catalog = await widget.controller.repository.listEffectiveCatalog(
        token,
      );
      final matches = catalog.where((item) => item.vaccineId == vaccine.id);
      if (!mounted) return;
      setState(() {
        _doses = matches.isEmpty ? null : matches.first.doses;
        _dosesError = matches.isEmpty
            ? 'Habilita la vacuna para consultar las dosis disponibles para la institución.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _dosesError = 'No se pudieron consultar las dosis del catálogo. Actualiza e intenta de nuevo.',
        );
      }
    }
  }

  Future<void> _loadStock() async {
    final inventory = widget.inventoryController;
    if (inventory == null ||
        !widget.offline.permissions.contains('INVENTORY_READ')) {
      return;
    }
    setState(() => _loadingStock = true);
    await inventory.loadLots(widget.institutionId);
    if (mounted) setState(() => _loadingStock = false);
  }

  Future<void> _addStock(List<Map<String, dynamic>> lots) async {
    final inventory = widget.inventoryController;
    if (inventory == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StockEntryPage(
          controller: inventory,
          institutionId: widget.institutionId,
          vaccineId: vaccine.id,
          vaccineName: vaccine.name,
          lots: lots,
        ),
      ),
    );
    if (mounted) {
      await _loadStock();
      if (mounted && saved == true) {
        AppSnackbar.success(context, 'Entrada registrada.');
      }
    }
  }

  List<({String type, String title, IconData icon})> get _groups => [
    if (vaccine.hasSyringe)
      (
        type: 'syringe',
        title: 'Jeringas disponibles',
        icon: Icons.medical_services_outlined,
      ),
    if (vaccine.hasLaboratory)
      (type: 'laboratory', title: 'Laboratorios', icon: Icons.science_outlined),
    if (vaccine.hasDropper)
      (type: 'dropper', title: 'Goteros', icon: Icons.water_drop_outlined),
    if (vaccine.hasObservation)
      (
        type: 'observation',
        title: 'Observaciones',
        icon: Icons.sticky_note_2_outlined,
      ),
  ];

  Future<void> _toggleEnabled(bool value) async {
    final ok = await widget.controller.setEnabled(
      vaccine,
      widget.institutionId,
      value,
      widget.offline,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {});
      AppSnackbar.success(
        context,
        value ? 'Vacuna habilitada.' : 'Vacuna deshabilitada.',
      );
    } else {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudo guardar el cambio.',
      );
    }
  }

  Future<void> _addOption(String type, String title) async {
    final value = await _editValue(title: 'Agregar · $title');
    if (!mounted || value == null || value.trim().isEmpty) return;
    final ok = await widget.controller.addOption(
      vaccine,
      optionPayload(fieldType: type, value: value.trim(), isDefault: false),
      institutionId: widget.institutionId,
      institutionScoped: true,
      offline: widget.offline,
    );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, '$title agregado.');
      await _load();
    } else {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudo agregar.',
      );
    }
  }

  Future<String?> _editValue({required String title, String? initial}) async {
    final text = TextEditingController(text: initial);
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: text,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Nombre o texto'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Este campo es obligatorio.'
                : null,
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, text.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, text.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    text.dispose();
    return result;
  }

  Future<void> _editOption(VaccineOption option) async {
    final value = await _editValue(
      title: 'Editar opción',
      initial: option.value,
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    final ok = await widget.controller.updateOption(
      vaccine,
      option,
      optionPayload(
        fieldType: option.fieldType,
        value: value.trim(),
        isDefault: option.isDefault,
        sortOrder: option.sortOrder,
        version: option.version,
      ),
      institutionId: widget.institutionId,
      institutionScoped: true,
      offline: widget.offline,
    );
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudo actualizar.',
      );
    }
  }

  Future<void> _disableOption(VaccineOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar opción'),
        content: Text(
          '“${option.displayName}” dejará de aparecer en nuevas atenciones. Los registros existentes se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.controller.disableOption(
      vaccine,
      option,
      institutionId: widget.institutionId,
      institutionScoped: true,
      offline: widget.offline,
    );
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudo desactivar.',
      );
    }
  }

  Future<void> _importSuggested() async {
    final ok = await widget.controller.importSuggested(
      vaccine,
      institutionId: widget.institutionId,
      offline: widget.offline,
    );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(
        context,
        'Se importaron las opciones sugeridas disponibles.',
      );
      await _load();
    } else {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudieron importar las opciones.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Configuración de vacuna'),
      actions: [
        IconButton(
          tooltip: 'Actualizar configuración y existencias',
          onPressed: _loadingOptions || _loadingStock ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _vaccineHeader(),
        const SizedBox(height: 20),
        _doseSection(),
        const SizedBox(height: 24),
        _stockSection(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuración institucional',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opciones que estarán disponibles al registrar una atención.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            if (widget.canWrite)
              TextButton.icon(
                onPressed: _importSuggested,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Sugeridas'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingOptions)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorPanel()
        else if (_groups.isEmpty)
          _emptyConfig()
        else
          for (final group in _groups) ...[
            _optionGroup(group.type, group.title, group.icon),
            const SizedBox(height: 12),
          ],
        if (vaccine.hasSyringeLot ||
            vaccine.hasDiluent ||
            vaccine.hasPneumococcalType ||
            vaccine.hasVialCount)
          _catalogManagedNote(),
      ],
    ),
  );

  Widget _vaccineHeader() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                vaccine.name.isEmpty
                    ? 'V'
                    : vaccine.name.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vaccine.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Código ${vaccine.code} · ${vaccine.category}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Habilitada en esta institución'),
          subtitle: Text(
            enabled
                ? 'Disponible para las atenciones nuevas.'
                : 'No aparecerá en nuevas atenciones.',
          ),
          value: enabled,
          onChanged: widget.canWrite ? _toggleEnabled : null,
        ),
      ],
    ),
  );

  Widget _stockSection() {
    final inventory = widget.inventoryController;
    final lots =
        inventory?.lots
            .where((lot) => lot['vaccineId'] == vaccine.id)
            .toList() ??
        const [];
    final available = lots.fold<int>(
      0,
      (sum, lot) => sum + ((lot['availableVials'] as num?)?.toInt() ?? 0),
    );
    final canRead = widget.offline.permissions.contains('INVENTORY_READ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existencias disponibles',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Frascos registrados en lotes de esta institución.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.slate),
        ),
        if (inventory != null &&
            canRead &&
            widget.offline.permissions.contains('INVENTORY_WRITE') &&
            widget.offline.status == SessionStatus.signedIn &&
            !_loadingStock &&
            inventory.error == null)
          TextButton.icon(
            onPressed: () => _addStock(lots),
            icon: const Icon(Icons.add),
            label: const Text('Agregar existencias'),
          ),
        const SizedBox(height: 12),
        if (!canRead)
          _notice(
            'No tienes permiso para consultar el saldo institucional.',
            Icons.lock_outline,
          )
        else if (_loadingStock)
          const LinearProgressIndicator()
        else if (inventory == null)
          _notice(
            'Inventario no disponible en esta pantalla.',
            Icons.info_outline,
          )
        else if (inventory.error != null)
          _notice(
            inventory.error!,
            Icons.cloud_off_outlined,
            action: _loadStock,
          )
        else if (lots.isEmpty)
          _notice(
            'Aún no hay lotes registrados para esta vacuna.',
            Icons.inventory_2_outlined,
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Saldo disponible',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$available frascos',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final lot in lots)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text('Lote ${lot['lotNumber'] ?? '—'}'),
              subtitle: Text(
                '${lot['manufacturer'] ?? 'Fabricante no indicado'} · Vence ${lot['expiresOn'] ?? 'sin fecha'}',
              ),
              trailing: Text(
                '${lot['availableVials'] ?? 0} frascos',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Este saldo corresponde a frascos de vacuna, no a jeringas físicas.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.slate),
          ),
        ],
      ],
    );
  }

  Widget _doseSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Dosis del esquema', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
        'Opciones del catálogo clínico, solo lectura. No representan existencias físicas.',
      ),
      const SizedBox(height: 12),
      if (_dosesError != null)
        _notice(_dosesError!, Icons.info_outline, action: _loadDoses)
      else if (_doses == null)
        const LinearProgressIndicator()
      else if (_doses!.isEmpty)
        _notice(
          'No hay dosis configuradas en el catálogo para esta vacuna.',
          Icons.info_outline,
        )
      else
        for (final dose in _doses!)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.medication_outlined),
            title: Text(dose.displayName),
            subtitle: dose.isDefault
                ? const Text('Seleccionada por defecto')
                : null,
          ),
    ],
  );

  Widget _optionGroup(String type, String title, IconData icon) {
    final options = _options
        .where((option) => option.fieldType == type && option.isActive)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.canWrite)
                  IconButton(
                    tooltip: 'Agregar $title',
                    onPressed: () => _addOption(type, title),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
              ],
            ),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No hay opciones agregadas.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.slate),
              ),
            )
          else
            for (final option in options)
              ListTile(
                dense: true,
                title: Text(option.displayName),
                subtitle: option.isDefault
                    ? const Text('Seleccionada por defecto')
                    : null,
                trailing: widget.canWrite
                    ? Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'Editar ${option.displayName}',
                            onPressed: () => _editOption(option),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Desactivar ${option.displayName}',
                            onPressed: () => _disableOption(option),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      )
                    : null,
              ),
        ],
      ),
    );
  }

  Widget _errorPanel() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ],
    ),
  );

  Widget _emptyConfig() => _notice(
    'Esta vacuna no tiene campos operativos institucionales configurables.',
    Icons.tune,
  );

  Widget _catalogManagedNote() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      'Los campos del formulario (lote de jeringa, diluyente, conteo y tipo de neumococo) dependen del catálogo clínico y no se cambian desde esta configuración institucional.',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.slate),
    ),
  );

  Widget _notice(String text, IconData icon, {VoidCallback? action}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.slate),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (action != null)
              IconButton(
                tooltip: 'Reintentar',
                onPressed: action,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      );
}
