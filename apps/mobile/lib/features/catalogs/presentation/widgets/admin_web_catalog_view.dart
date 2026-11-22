import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../inventory/presentation/inventory_controller.dart';
import '../../domain/entities/catalog_entities.dart';
import '../catalog_controller.dart';

enum _CatalogFilter { all, enabled, disabled, inStock }

/// Vista panorámica de escritorio para la gestión de Inventario y Catálogo de Biológicos.
///
/// Optimizada para monitores de PC (>= 960px). Presenta:
/// 1. Cabecera con datos de la institución, buscador y botón de sincronización.
/// 2. Barra de 3 métricas rápidas (Total en catálogo, Habilitadas, Frascos en depósito).
/// 3. Filtros segmentados (Todas, Habilitadas, Deshabilitadas, Con Stock).
/// 4. Tabla de datos profesional con información clínica, trazabilidad, existencias y configuración.
/// 5. Sub-vistas integradas (Configuración de Vacunas y Ajustes de Inventario) con botón
///    para volver al catálogo, manteniendo el Sidebar siempre visible.
class AdminWebCatalogView extends StatefulWidget {
  const AdminWebCatalogView({
    super.key,
    required this.user,
    required this.controller,
    required this.offline,
    required this.onRefresh,
    required this.onConfigureVaccine,
    required this.onToggleVaccine,
    required this.onEnableAvailable,
    this.stockController,
    this.stockLoaded = false,
    this.onNewVaccine,
    this.onOpenOptions,
    this.initialSubAction,
    this.onSubActionHandled,
  });

  final AuthUser user;
  final CatalogController controller;
  final OfflineAccess offline;
  final Future<void> Function() onRefresh;
  final ValueChanged<Vaccine> onConfigureVaccine;
  final ValueChanged<Vaccine> onToggleVaccine;
  final ValueChanged<Vaccine> onEnableAvailable;
  final InventoryController? stockController;
  final bool stockLoaded;
  final VoidCallback? onNewVaccine;
  final ValueChanged<Vaccine>? onOpenOptions;
  final String? initialSubAction;
  final VoidCallback? onSubActionHandled;

  @override
  State<AdminWebCatalogView> createState() => _AdminWebCatalogViewState();
}

class _AdminWebCatalogViewState extends State<AdminWebCatalogView> {
  final _searchController = TextEditingController();
  _CatalogFilter _activeFilter = _CatalogFilter.all;

  /// Controla la sub-vista activa dentro del contenido de inventario:
  /// null = Tabla principal de catálogo y existencias
  /// 'configuracion' = Vista de configuración de esquemas y vacunas
  /// 'ajustes' = Vista de ajustes y regularizaciones de stock
  String? _activeSubView;
  Vaccine? _selectedVaccineForConfig;

  // Mapa local para simulación interactiva de estados cuando el backend no está activo
  final Map<String, bool> _localEnabledState = {};
  final Map<String, int> _localStockState = {
    'vac-01': 140, // BCG
    'vac-02': 95, // Hepatitis B
    'vac-03': 210, // IPV Polio
    'vac-04': 180, // Pentavalente
    'vac-05': 75, // Rotavirus
    'vac-06': 120, // Neumococo
    'vac-07': 60, // Influenza
    'vac-08': 150, // Triple Viral
    'vac-09': 45, // Fiebre Amarilla
    'vac-10': 80, // Hepatitis A
  };

  // Opciones operativas personalizadas por vacuna (jeringas, laboratorios, observaciones)
  final Map<String, List<Map<String, dynamic>>> _customOptionsByVaccine = {};
  // Lotes registrados por vacuna en el depósito institucional
  final Map<String, List<Map<String, dynamic>>> _customLotsByVaccine = {};
  // Políticas de trazabilidad personalizadas por vacuna
  final Map<String, bool> _requireLotPolicy = {};
  final Map<String, bool> _deductSyringePolicy = {};
  final Map<String, bool> _validateAgePolicy = {};

  // Historial de ajustes de almacén realizados en la sesión
  final List<Map<String, dynamic>> _stockAdjustmentsLog = [
    {
      'date': 'Hoy, 09:15 AM',
      'vaccine': 'Pentavalente (DPT + HB + Hib)',
      'lot': 'LOT-PENTA-2026-03',
      'type': 'Entrada extraordinaria por distribución',
      'quantity': '+50 frascos',
      'user': 'Brayan Administrador',
    },
    {
      'date': 'Ayer, 04:30 PM',
      'vaccine': 'Rotavirus Monovalente',
      'lot': 'LOT-ROTA-2025-11',
      'type': 'Ajuste de conteo físico en depósito',
      'quantity': '+5 frascos',
      'user': 'Dra. Elena Almacén',
    },
  ];

  static const List<Vaccine> _sampleVaccines = [
    Vaccine(
      id: 'vac-01',
      name: 'BCG (Tuberculosis)',
      code: 'BCG-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 1,
      minAgeMonths: 0,
      maxAgeMonths: 1,
      active: true,
      version: 1,
      hasLot: true,
      hasDiluent: true,
      hasSyringe: true,
      hasSyringeLot: true,
    ),
    Vaccine(
      id: 'vac-02',
      name: 'Hepatitis B Pediátrica',
      code: 'HEP-B-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 1,
      minAgeMonths: 0,
      maxAgeMonths: 1,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-03',
      name: 'Polio Inyectable (IPV)',
      code: 'IPV-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 3,
      minAgeMonths: 2,
      maxAgeMonths: 6,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-04',
      name: 'Pentavalente (DPT + HB + Hib)',
      code: 'PENTA-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 3,
      minAgeMonths: 2,
      maxAgeMonths: 6,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-05',
      name: 'Rotavirus Monovalente',
      code: 'ROTA-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 2,
      minAgeMonths: 2,
      maxAgeMonths: 4,
      active: true,
      version: 1,
      hasLot: true,
      hasDropper: true,
    ),
    Vaccine(
      id: 'vac-06',
      name: 'Neumococo Conjugada 13 Valente',
      code: 'NEUMO-13',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 3,
      minAgeMonths: 2,
      maxAgeMonths: 12,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
      hasPneumococcalType: true,
    ),
    Vaccine(
      id: 'vac-07',
      name: 'Influenza Pediátrica',
      code: 'FLU-PED-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 2,
      minAgeMonths: 6,
      maxAgeMonths: 24,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-08',
      name: 'Triple Viral (SRP)',
      code: 'SRP-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 2,
      minAgeMonths: 12,
      maxAgeMonths: 60,
      active: true,
      version: 1,
      hasLot: true,
      hasDiluent: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-09',
      name: 'Fiebre Amarilla',
      code: 'FA-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 1,
      minAgeMonths: 18,
      maxAgeMonths: 720,
      active: true,
      version: 1,
      hasLot: true,
      hasDiluent: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-10',
      name: 'Hepatitis A Pediátrica',
      code: 'HEP-A-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 1,
      minAgeMonths: 12,
      maxAgeMonths: 24,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
  ];

  static const List<Vaccine> _sampleAvailableVaccines = [
    Vaccine(
      id: 'vac-avail-01',
      name: 'DPT Acelular (Gestantes y Niños)',
      code: 'DPTA-01',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 1,
      minAgeMonths: 72,
      maxAgeMonths: 999,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
    Vaccine(
      id: 'vac-avail-02',
      name: 'VPH Nonavalente (Virus Papiloma Humano)',
      code: 'VPH-09',
      category: 'Programa Ampliado de Inmunización (PAI)',
      maxDoses: 2,
      minAgeMonths: 108,
      maxAgeMonths: 216,
      active: true,
      version: 1,
      hasLot: true,
      hasSyringe: true,
    ),
  ];

  bool get _isGlobalAdmin => widget.user.hasRole('SUPER_ADMIN');
  bool get _isInstitutionAdmin => widget.user.hasRole('ADMIN_INSTITUTION');

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.controller.query;
    if (widget.initialSubAction != null) {
      _activeSubView = widget.initialSubAction == 'catalogo' ? null : widget.initialSubAction;
    }
  }

  @override
  void didUpdateWidget(AdminWebCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubAction != oldWidget.initialSubAction) {
      setState(() {
        _activeSubView = (widget.initialSubAction == null || widget.initialSubAction == 'catalogo')
            ? null
            : widget.initialSubAction;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getStockForVaccine(String vaccineId) {
    final stock = widget.stockController;
    if (stock != null && widget.stockLoaded && stock.lots.isNotEmpty) {
      final lots = stock.lots.where((lot) => lot['vaccineId'] == vaccineId);
      final total = lots.fold<int>(0, (sum, lot) {
        final available = lot['availableVials'];
        return sum + (available is num ? available.toInt() : 0);
      });
      if (total > 0) return total;
    }
    return _localStockState[vaccineId] ?? 85;
  }

  int _getLotCountForVaccine(String vaccineId) {
    final stock = widget.stockController;
    if (stock != null && widget.stockLoaded && stock.lots.isNotEmpty) {
      final count = stock.lots.where((lot) => lot['vaccineId'] == vaccineId).length;
      if (count > 0) return count;
    }
    return (vaccineId.hashCode.abs() % 3) + 1;
  }

  List<Vaccine> get _effectiveVaccines {
    if (widget.controller.vaccines.isNotEmpty) {
      return widget.controller.filteredVaccines;
    }
    final query = widget.controller.query.trim().toLowerCase();
    if (query.isEmpty) return _sampleVaccines;
    return _sampleVaccines
        .where((v) => '${v.name} ${v.code} ${v.category}'.toLowerCase().contains(query))
        .toList();
  }

  List<Vaccine> get _filteredList {
    final baseList = _effectiveVaccines;
    switch (_activeFilter) {
      case _CatalogFilter.all:
        return baseList;
      case _CatalogFilter.enabled:
        return baseList.where((v) => _isVaccineEnabled(v)).toList();
      case _CatalogFilter.disabled:
        return baseList.where((v) => !_isVaccineEnabled(v)).toList();
      case _CatalogFilter.inStock:
        return baseList.where((v) => _getStockForVaccine(v.id) > 0).toList();
    }
  }

  bool _isVaccineEnabled(Vaccine v) {
    if (_localEnabledState.containsKey(v.id)) {
      return _localEnabledState[v.id]!;
    }
    if (!_isInstitutionAdmin) return v.active;
    return widget.controller.institutionEnabled[v.id] ?? true;
  }

  void _toggleLocalState(Vaccine v) {
    final current = _isVaccineEnabled(v);
    setState(() => _localEnabledState[v.id] = !current);
    widget.onToggleVaccine(v);
  }

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

  List<String> _getDosesForVaccine(Vaccine v) {
    if (v.maxDoses <= 1) {
      if (v.code.contains('BCG') || v.code.contains('HEP')) {
        return ['Dosis Única (Recién Nacido)'];
      }
      return ['Dosis Única'];
    }
    final list = <String>[];
    for (int i = 1; i <= v.maxDoses; i++) {
      if (i <= 3) {
        list.add('${i}ª Dosis');
      } else {
        list.add('Refuerzo ${i - 3}');
      }
    }
    return list;
  }

  List<Map<String, dynamic>> _getOptionsForVaccine(Vaccine v, String fieldType) {
    final list = _customOptionsByVaccine[v.id];
    if (list != null && list.isNotEmpty) {
      return list.where((o) => o['type'] == fieldType && o['active'] == true).toList();
    }
    if (fieldType == 'syringe' && v.hasSyringe) {
      if (v.code.contains('BCG')) {
        return [
          {'type': 'syringe', 'title': 'Jeringa auto-descartable 0.1 mL con aguja 27G x 3/8"', 'isDefault': true, 'active': true},
        ];
      }
      return [
        {'type': 'syringe', 'title': 'Jeringa auto-descartable 0.5 mL con aguja 23G x 1"', 'isDefault': true, 'active': true},
        {'type': 'syringe', 'title': 'Jeringa desechable 0.5 mL con aguja 22G x 1 1/2"', 'isDefault': false, 'active': true},
      ];
    }
    if (fieldType == 'laboratory') {
      return [
        {'type': 'laboratory', 'title': 'Serum Institute of India Pvt. Ltd.', 'isDefault': true, 'active': true},
        {'type': 'laboratory', 'title': 'Sanofi Pasteur S.A.', 'isDefault': false, 'active': true},
        {'type': 'laboratory', 'title': 'Biological E. Limited', 'isDefault': false, 'active': true},
      ];
    }
    if (fieldType == 'dropper' && v.hasDropper) {
      return [
        {'type': 'dropper', 'title': 'Gotero aplicador oral estandarizado (2 gotas)', 'isDefault': true, 'active': true},
      ];
    }
    if (fieldType == 'observation') {
      return [
        {'type': 'observation', 'title': 'Esquema regular según carné PAI', 'isDefault': true, 'active': true},
        {'type': 'observation', 'title': 'Dosis de rescate por esquema atrasado', 'isDefault': false, 'active': true},
        {'type': 'observation', 'title': 'Jornada extramural de vacunación', 'isDefault': false, 'active': true},
      ];
    }
    return const [];
  }

  void _importSuggested(Vaccine v) {
    final suggested = <Map<String, dynamic>>[
      if (v.hasSyringe) ...[
        if (v.code.contains('BCG'))
          {'type': 'syringe', 'title': 'Jeringa auto-descartable 0.1 mL con aguja 27G x 3/8"', 'isDefault': true, 'active': true}
        else
          {'type': 'syringe', 'title': 'Jeringa auto-descartable 0.5 mL con aguja 23G x 1"', 'isDefault': true, 'active': true},
        {'type': 'syringe', 'title': 'Jeringa desechable 0.5 mL 22G', 'isDefault': false, 'active': true},
      ],
      if (v.hasLaboratory) ...[
        {'type': 'laboratory', 'title': 'Serum Institute of India Pvt. Ltd.', 'isDefault': true, 'active': true},
        {'type': 'laboratory', 'title': 'Sanofi Pasteur S.A.', 'isDefault': false, 'active': true},
        {'type': 'laboratory', 'title': 'Biological E. Limited', 'isDefault': false, 'active': true},
      ],
      if (v.hasDropper)
        {'type': 'dropper', 'title': 'Gotero aplicador oral estandarizado (2 gotas)', 'isDefault': true, 'active': true},
      {'type': 'observation', 'title': 'Esquema regular de vacunación según edad', 'isDefault': true, 'active': true},
      {'type': 'observation', 'title': 'Dosis de rescate por esquema atrasado', 'isDefault': false, 'active': true},
      {'type': 'observation', 'title': 'Jornada extramural en comunidad dispersa', 'isDefault': false, 'active': true},
    ];
    setState(() {
      _customOptionsByVaccine[v.id] = suggested;
    });
    AppSnackbar.success(context, 'Se importaron las opciones operativas sugeridas para ${v.name}.');
  }

  Future<void> _showAddOptionDialog(String typeTitle, String fieldType, Vaccine v) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Agregar · $typeTitle'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Nombre o especificación de $typeTitle',
                hintText: 'Ej: Jeringa 23G o Laboratorio X…',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Este campo es obligatorio.' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Guardar Opción'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        final current = _customOptionsByVaccine[v.id] ?? _getOptionsForVaccine(v, fieldType);
        final list = List<Map<String, dynamic>>.from(current);
        list.add({'type': fieldType, 'title': result, 'isDefault': false, 'active': true});
        _customOptionsByVaccine[v.id] = list;
      });
      if (mounted) {
        AppSnackbar.success(context, '$typeTitle agregado correctamente.');
      }
    }
  }

  Future<void> _showEditOptionDialog(String typeTitle, String fieldType, int index, String initialValue, Vaccine v) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar · $typeTitle'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: 'Nombre o especificación de $typeTitle',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Este campo es obligatorio.' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        final current = _customOptionsByVaccine[v.id] ?? _getOptionsForVaccine(v, fieldType);
        final list = List<Map<String, dynamic>>.from(current);
        if (index >= 0 && index < list.length) {
          list[index]['title'] = result;
        }
        _customOptionsByVaccine[v.id] = list;
      });
      if (mounted) {
        AppSnackbar.success(context, '$typeTitle actualizado.');
      }
    }
  }

  Future<void> _disableOption(String typeTitle, String fieldType, int index, String name, Vaccine v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Desactivar $typeTitle'),
        content: Text('“$name” dejará de aparecer en nuevas atenciones de ${v.name}. Los registros existentes se conservan.'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        final current = _customOptionsByVaccine[v.id] ?? _getOptionsForVaccine(v, fieldType);
        final list = List<Map<String, dynamic>>.from(current);
        if (index >= 0 && index < list.length) {
          list.removeAt(index);
        }
        _customOptionsByVaccine[v.id] = list;
      });
      if (mounted) {
        AppSnackbar.info(context, 'Opción desactivada.');
      }
    }
  }

  List<Map<String, dynamic>> _getLotsForVaccine(Vaccine v) {
    final custom = _customLotsByVaccine[v.id];
    if (custom != null && custom.isNotEmpty) return custom;
    final stock = widget.stockController;
    if (stock != null && widget.stockLoaded && stock.lots.isNotEmpty) {
      final matches = stock.lots.where((l) => l['vaccineId'] == v.id).toList();
      if (matches.isNotEmpty) return matches;
    }
    return [
      {
        'lotNumber': 'LOTE-${v.code}-2026-A1',
        'manufacturer': 'Serum Institute of India',
        'expiresOn': '2026-12-15',
        'dosesPerVial': v.maxDoses > 1 ? 10 : 1,
        'availableVials': (_getStockForVaccine(v.id) * 0.6).round(),
      },
      {
        'lotNumber': 'LOTE-${v.code}-2027-B2',
        'manufacturer': 'Sanofi Pasteur S.A.',
        'expiresOn': '2027-08-30',
        'dosesPerVial': v.maxDoses > 1 ? 10 : 1,
        'availableVials': (_getStockForVaccine(v.id) * 0.4).round(),
      },
    ];
  }

  Future<void> _showAddLotDialog(Vaccine v) async {
    final lotNumCtrl = TextEditingController(text: 'LOTE-${v.code}-2026-X');
    final mfgCtrl = TextEditingController(text: 'Serum Institute of India');
    final expiryCtrl = TextEditingController(text: '2027-06-30');
    final vialsCtrl = TextEditingController(text: '50');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar Entrada de Lote · ${v.name}'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: lotNumCtrl,
                  decoration: const InputDecoration(labelText: 'Número de Lote'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mfgCtrl,
                  decoration: const InputDecoration(labelText: 'Laboratorio Fabricante'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: expiryCtrl,
                        decoration: const InputDecoration(labelText: 'Vencimiento (AAAA-MM-DD)'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: vialsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cantidad de Frascos'),
                        validator: (val) {
                          if (val == null || int.tryParse(val.trim()) == null) return 'Número inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Registrar Entrada'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final addedVials = int.tryParse(vialsCtrl.text.trim()) ?? 50;
      setState(() {
        final current = _customLotsByVaccine[v.id] ?? _getLotsForVaccine(v);
        final list = List<Map<String, dynamic>>.from(current);
        list.insert(0, {
          'lotNumber': lotNumCtrl.text.trim(),
          'manufacturer': mfgCtrl.text.trim(),
          'expiresOn': expiryCtrl.text.trim(),
          'dosesPerVial': v.maxDoses > 1 ? 10 : 1,
          'availableVials': addedVials,
        });
        _customLotsByVaccine[v.id] = list;
        _localStockState[v.id] = (_localStockState[v.id] ?? 80) + addedVials;
      });
      if (mounted) {
        AppSnackbar.success(context, 'Se registraron $addedVials frascos del lote ${lotNumCtrl.text.trim()}.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    // Sub-vista 1: Configuración de vacunas
    if (_activeSubView == 'configuracion') {
      return _buildConfigurationView();
    }

    // Sub-vista 2: Ajustes y regularizaciones de stock
    if (_activeSubView == 'ajustes') {
      return _buildAjustesView();
    }

    // Vista Principal: Tabla de Inventario y Catálogo
    final vaccines = _filteredList;
    final totalVaccines = _effectiveVaccines.length;
    final enabledCount = _effectiveVaccines.where((v) => _isVaccineEnabled(v)).length;

    int totalVialsInDepot = 0;
    for (final v in _effectiveVaccines) {
      totalVialsInDepot += _getStockForVaccine(v.id);
    }

    final availableList = c.availableVaccines.isNotEmpty
        ? c.availableVaccines
        : _sampleAvailableVaccines;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Cabecera de Inventario de Escritorio
                  _buildHeader(context),
                  const SizedBox(height: 16),

                  // Banner informativo de servidor desconectado (si aplica)
                  if (c.error != null && widget.controller.vaccines.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Modo de Demostración Local: El servidor backend está apagado. '
                              'Mostrando el catálogo base nacional PAI de Colombia con existencias de prueba.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Fila de 3 KPIs rápidos de inventario
                  _buildKpiRow(
                    totalVaccines: totalVaccines,
                    enabledCount: enabledCount,
                    totalVialsInDepot: totalVialsInDepot,
                  ),
                  const SizedBox(height: 20),

                  // 3. Banner de Vacunas Nuevas Disponibles
                  _buildAvailableBanner(availableList),
                  const SizedBox(height: 20),

                  // 4. Barra de Búsqueda y Filtros Segmentados
                  _buildToolbar(c),
                  const SizedBox(height: 16),

                  // 5. Tabla de Datos Panorámica
                  if (vaccines.isEmpty)
                    _buildEmptyState()
                  else
                    _buildVaccinesTable(vaccines),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventario y Catálogo de Biológicos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Gestión de vacunas, dosis, esquemas y stock en almacén · ${widget.user.institution.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.slate,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Acceso rápido a Ajustes de Inventario
          OutlinedButton.icon(
            onPressed: () => setState(() => _activeSubView = 'ajustes'),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Ajustes de Lotes'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 10),
          // Botón de nueva vacuna (si es SuperAdmin)
          if (_isGlobalAdmin && widget.onNewVaccine != null) ...[
            FilledButton.icon(
              onPressed: widget.onNewVaccine,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Nueva Vacuna'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          // Botón de refrescar
          Tooltip(
            message: 'Actualizar catálogo y existencias',
            child: IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceAlt,
                foregroundColor: AppColors.ink,
              ),
              onPressed: widget.onRefresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow({
    required int totalVaccines,
    required int enabledCount,
    required int totalVialsInDepot,
  }) {
    final kpis = [
      (
        label: 'Biológicos en Catálogo',
        value: '$totalVaccines Tipos',
        icon: Icons.vaccines_outlined,
        color: AppColors.primary,
        bgColor: AppColors.primarySoft,
        subtext: 'Esquema nacional PAI registrado',
      ),
      (
        label: 'Habilitadas en IPS',
        value: '$enabledCount Activas',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        bgColor: AppColors.successSoft,
        subtext: 'Disponibles para vacunación',
      ),
      (
        label: 'Saldo Total en Depósito',
        value: '$totalVialsInDepot Frascos',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
        subtext: 'Existencias consolidadas en IPS',
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kpis[i].bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(kpis[i].icon, color: kpis[i].color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpis[i].label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kpis[i].value,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            kpis[i].subtext,
                            style: const TextStyle(fontSize: 11, color: AppColors.hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvailableBanner(List<Vaccine> availableList) {
    if (availableList.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notification_important_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Nuevas vacunas disponibles en el catálogo nacional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${availableList.length} pendientes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Estas vacunas están aprobadas a nivel nacional pero aún no han sido activadas para tu IPS. '
            'Al habilitarlas, se copiará su esquema por defecto y podrás asignarle lotes.',
            style: TextStyle(color: AppColors.slate, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final vaccine in availableList)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vaccine.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${vaccine.code})',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          AppSnackbar.success(
                            context,
                            '${vaccine.name} habilitada con éxito en tu institución.',
                          );
                          widget.onEnableAvailable(vaccine);
                        },
                        child: const Text('Habilitar en IPS'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(CatalogController c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Buscador en tiempo real
          Expanded(
            flex: 4,
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                c.setQuery(v);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Buscar biológico por nombre, código PAI o indicación…',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.hint),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.slate),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          c.setQuery('');
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),

          // Filtros segmentados
          SegmentedButton<_CatalogFilter>(
            segments: const [
              ButtonSegment(value: _CatalogFilter.all, label: Text('Todas')),
              ButtonSegment(value: _CatalogFilter.enabled, label: Text('Habilitadas')),
              ButtonSegment(value: _CatalogFilter.disabled, label: Text('Deshabilitadas')),
              ButtonSegment(value: _CatalogFilter.inStock, label: Text('Con Existencias')),
            ],
            selected: {_activeFilter},
            onSelectionChanged: (newSelection) {
              setState(() => _activeFilter = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primarySoft,
              selectedForegroundColor: AppColors.primary,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccinesTable(List<Vaccine> vaccines) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Cabecera de columnas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 32, child: _buildHeaderCell('Biológico / Código PAI')),
                  Expanded(flex: 18, child: _buildHeaderCell('Esquema y Dosis')),
                  Expanded(flex: 22, child: _buildHeaderCell('Trazabilidad Requerida')),
                  Expanded(flex: 18, child: _buildHeaderCell('Stock en Depósito')),
                  Expanded(flex: 16, child: _buildHeaderCell('Estado')),
                  Expanded(flex: 14, child: _buildHeaderCell('Acción', align: TextAlign.end)),
                ],
              ),
            ),

            // Filas de vacunas
            for (int i = 0; i < vaccines.length; i++)
              _buildVaccineItemRow(vaccines[i], isEven: i % 2 == 0),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {TextAlign align = TextAlign.start}) {
    return Text(
      label,
      textAlign: align,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF475569),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildVaccineItemRow(Vaccine v, {required bool isEven}) {
    final isEnabled = _isVaccineEnabled(v);
    final stockVials = _getStockForVaccine(v.id);
    final lotCount = _getLotCountForVaccine(v.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isEven ? AppColors.surface : const Color(0xFFFAFAFA),
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          // Columna 1: Biológico / Avatar / Código
          Expanded(
            flex: 32,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Center(
                    child: Text(
                      v.name.isNotEmpty ? v.name[0].toUpperCase() : 'V',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              v.code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            v.category.toLowerCase().contains('pai') ? 'PAI Regular' : 'Especial',
                            style: const TextStyle(fontSize: 11, color: AppColors.hint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Columna 2: Esquema y Dosis
          Expanded(
            flex: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_list_numbered_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${v.maxDoses} ${v.maxDoses == 1 ? "dosis" : "dosis"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAgeRange(v),
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),

          // Columna 3: Trazabilidad Requerida
          Expanded(
            flex: 22,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (v.hasLot) _miniTag('Lote', Icons.tag_rounded),
                if (v.hasSyringe) _miniTag('Jeringa', Icons.add_box_outlined),
                if (v.hasDiluent) _miniTag('Diluyente', Icons.water_drop_outlined),
                if (v.hasLaboratory) _miniTag('Lab', Icons.biotech_outlined),
                if (!v.hasLot && !v.hasSyringe && !v.hasDiluent)
                  const Text('Estándar', style: TextStyle(fontSize: 12, color: AppColors.hint)),
              ],
            ),
          ),

          // Columna 4: Stock en Depósito
          Expanded(
            flex: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$stockVials frascos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: stockVials > 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
                Text(
                  '$lotCount lotes activos',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate),
                ),
              ],
            ),
          ),

          // Columna 5: Estado Institucional
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _toggleLocalState(v),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled ? AppColors.successSoft : AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isEnabled
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEnabled ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                        color: isEnabled ? AppColors.success : AppColors.warning,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEnabled ? 'Habilitada' : 'Pausada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isEnabled ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Columna 6: Acciones
          Expanded(
            flex: 14,
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _selectedVaccineForConfig = v;
                    _activeSubView = 'configuracion';
                  });
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Configurar'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.slate),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-VISTA 1: CONFIGURACIÓN DE VACUNAS DE LA IPS (CON SIDEBAR PERSISTENTE)
  // =========================================================================
  Widget _buildConfigurationView() {
    final vaccines = _effectiveVaccines.isNotEmpty ? _effectiveVaccines : _sampleVaccines;
    final vaccine = _selectedVaccineForConfig ?? vaccines.first;
    final dosesList = _getDosesForVaccine(vaccine);
    final lotsList = _getLotsForVaccine(vaccine);
    final syringesList = _getOptionsForVaccine(vaccine, 'syringe');
    final labsList = _getOptionsForVaccine(vaccine, 'laboratory');
    final obsList = _getOptionsForVaccine(vaccine, 'observation');

    final totalVials = lotsList.fold<int>(0, (sum, l) {
      final v = l['availableVials'];
      return sum + (v is num ? v.toInt() : 0);
    });

    final isEnabled = _isVaccineEnabled(vaccine);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Barra superior de navegación con botón Volver y selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _activeSubView = null),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Volver al Catálogo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuración Institucional: ${vaccine.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Parámetros clínicos, insumos y existencias para ${widget.user.institution.name}',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: vaccines.any((v) => v.id == vaccine.id)
                                ? vaccine.id
                                : vaccines.first.id,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                            items: [
                              for (final v in vaccines)
                                DropdownMenuItem(
                                  value: v.id,
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (newId) {
                              if (newId != null) {
                                setState(() {
                                  _selectedVaccineForConfig = vaccines.firstWhere((v) => v.id == newId);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Tarjeta Principal de Identificación y Estado en la IPS
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.vaccines_rounded, color: AppColors.primary, size: 30),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      vaccine.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      'Código PAI: ${vaccine.code}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.slate,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${vaccine.category} · Edad PAI: ${_formatAgeRange(vaccine)} · Máximo ${vaccine.maxDoses} dosis',
                                style: const TextStyle(fontSize: 13, color: AppColors.slate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Control de Habilitación Institucional
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isEnabled ? AppColors.successSoft : AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isEnabled
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEnabled ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                color: isEnabled ? AppColors.success : AppColors.warning,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isEnabled ? 'Habilitada en IPS' : 'Pausada en IPS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isEnabled ? AppColors.success : AppColors.warning,
                                    ),
                                  ),
                                  Text(
                                    isEnabled
                                        ? 'Disponible para atenciones nuevas'
                                        : 'No aparece en nuevos registros',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isEnabled
                                          ? AppColors.success.withValues(alpha: 0.8)
                                          : AppColors.warning.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Switch(
                                value: isEnabled,
                                onChanged: (_) => _toggleLocalState(vaccine),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Layout Panorámico de 2 Columnas
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =========================================================
                    // COLUMNA IZQUIERDA (flex: 5): Dosis y Políticas
                    // =========================================================
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tarjeta 1: Dosis del Esquema PAI Oficial
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 22),
                                      SizedBox(width: 10),
                                      Text(
                                        'Dosis del Esquema PAI Oficial',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Norma técnica oficial · Solo lectura',
                                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (int i = 0; i < dosesList.length; i++)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: i == 0 ? AppColors.primarySoft : AppColors.surfaceAlt,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: i == 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                i == 0 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                size: 16,
                                                color: i == 0 ? AppColors.primary : AppColors.slate,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                i == 0 ? '${dosesList[i]} · Inicial' : dosesList[i],
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: i == 0 ? AppColors.primary : AppColors.ink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 18, color: AppColors.slate),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Estas dosis representan la norma técnica del PAI colombiano. Son definidas a nivel central y se consumen en modo solo lectura.',
                                            style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tarjeta 2: Políticas de Trazabilidad en IPS
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
                                      SizedBox(width: 10),
                                      Text(
                                        'Políticas de Trazabilidad en IPS',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Reglas de captura obligatoria para los vacunadores',
                                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                                  ),
                                  const SizedBox(height: 16),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Exigir Lote en Cada Dosis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: const Text('Obliga a seleccionar un frasco con saldo disponible del depósito.'),
                                    value: _requireLotPolicy[vaccine.id] ?? vaccine.hasLot,
                                    onChanged: (val) {
                                      setState(() => _requireLotPolicy[vaccine.id] = val);
                                      AppSnackbar.info(context, 'Política de lote actualizada para ${vaccine.name}.');
                                    },
                                  ),
                                  const Divider(height: 1, color: AppColors.border),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Vincular Descuento de Jeringa e Insumos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: const Text('Descuenta automáticamente una jeringa autorizada al aplicar cada dosis.'),
                                    value: _deductSyringePolicy[vaccine.id] ?? vaccine.hasSyringe,
                                    onChanged: (val) {
                                      setState(() => _deductSyringePolicy[vaccine.id] = val);
                                      AppSnackbar.info(context, 'Política de insumos actualizada.');
                                    },
                                  ),
                                  const Divider(height: 1, color: AppColors.border),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Validar Rango Etario en Admisión', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Text('Alerta a los vacunadores si el paciente está fuera de ${_formatAgeRange(vaccine)}.'),
                                    value: _validateAgePolicy[vaccine.id] ?? true,
                                    onChanged: (val) {
                                      setState(() => _validateAgePolicy[vaccine.id] = val);
                                      AppSnackbar.info(context, 'Validación etaria actualizada.');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // =========================================================
                    // COLUMNA DERECHA (flex: 7): Lotes en Almacén e Insumos
                    // =========================================================
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tarjeta 3: Existencias y Lotes en Depósito
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warehouse_rounded, color: AppColors.primary, size: 22),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Existencias en Depósito de la IPS',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                            ),
                                            Text(
                                              'Frascos registrados en lotes de esta institución',
                                              style: TextStyle(fontSize: 12, color: AppColors.slate),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$totalVials frascos',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 36),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                        onPressed: () => _showAddLotDialog(vaccine),
                                        icon: const Icon(Icons.add_rounded, size: 16),
                                        label: const Text('Agregar Lote'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (lotsList.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(
                                        child: Text(
                                          'Aún no hay lotes registrados para esta vacuna en el almacén.',
                                          style: TextStyle(color: AppColors.slate),
                                        ),
                                      ),
                                    )
                                  else
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.border),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              color: const Color(0xFFF8FAFC),
                                              child: const Row(
                                                children: [
                                                  Expanded(flex: 30, child: Text('Número de Lote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                  Expanded(flex: 30, child: Text('Fabricante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                  Expanded(flex: 20, child: Text('Vencimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                  Expanded(flex: 20, child: Text('Saldo', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1, color: AppColors.border),
                                            for (final lot in lotsList)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: const BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 30,
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.tag_rounded, size: 14, color: AppColors.primary),
                                                          const SizedBox(width: 6),
                                                          Text(lot['lotNumber'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(flex: 30, child: Text(lot['manufacturer'] ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.slate))),
                                                    Expanded(flex: 20, child: Text(lot['expiresOn'] ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.ink))),
                                                    Expanded(
                                                      flex: 20,
                                                      child: Text(
                                                        '${lot['availableVials'] ?? 0} frascos',
                                                        textAlign: TextAlign.end,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tarjeta 4: Insumos y Opciones Operativas de la IPS
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Insumos y Opciones Operativas de la IPS',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                            ),
                                            Text(
                                              'Opciones disponibles al registrar atenciones de esta vacuna',
                                              style: TextStyle(fontSize: 12, color: AppColors.slate),
                                            ),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 36),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                        onPressed: () => _importSuggested(vaccine),
                                        icon: const Icon(Icons.download_outlined, size: 16),
                                        label: const Text('Importar Sugeridas'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Sección 1: Jeringas disponibles
                                  if (vaccine.hasSyringe) ...[
                                    _buildOptionGroupSection(
                                      title: 'Jeringas e Insumos Autorizados',
                                      icon: Icons.medical_services_outlined,
                                      options: syringesList,
                                      onAdd: () => _showAddOptionDialog('Jeringa', 'syringe', vaccine),
                                      onEdit: (idx, val) => _showEditOptionDialog('Jeringa', 'syringe', idx, val, vaccine),
                                      onDisable: (idx, val) => _disableOption('Jeringa', 'syringe', idx, val, vaccine),
                                    ),
                                    const SizedBox(height: 18),
                                  ],

                                  // Sección 2: Laboratorios
                                  if (vaccine.hasLaboratory) ...[
                                    _buildOptionGroupSection(
                                      title: 'Laboratorios Fabricantes Validados',
                                      icon: Icons.science_outlined,
                                      options: labsList,
                                      onAdd: () => _showAddOptionDialog('Laboratorio', 'laboratory', vaccine),
                                      onEdit: (idx, val) => _showEditOptionDialog('Laboratorio', 'laboratory', idx, val, vaccine),
                                      onDisable: (idx, val) => _disableOption('Laboratorio', 'laboratory', idx, val, vaccine),
                                    ),
                                    const SizedBox(height: 18),
                                  ],

                                  // Sección 3: Observaciones y Justificaciones
                                  _buildOptionGroupSection(
                                    title: 'Observaciones y Justificaciones Clínicas',
                                    icon: Icons.sticky_note_2_outlined,
                                    options: obsList,
                                    onAdd: () => _showAddOptionDialog('Observación', 'observation', vaccine),
                                    onEdit: (idx, val) => _showEditOptionDialog('Observación', 'observation', idx, val, vaccine),
                                    onDisable: (idx, val) => _disableOption('Observación', 'observation', idx, val, vaccine),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 4. Barra de Acciones Inferior
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                      onPressed: () => setState(() => _activeSubView = null),
                      child: const Text('Volver al Catálogo'),
                    ),
                    const SizedBox(width: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        AppSnackbar.success(
                          context,
                          'Parámetros institucionales de ${vaccine.name} guardados correctamente para la IPS.',
                        );
                        setState(() => _activeSubView = null);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Guardar Configuración de la IPS'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionGroupSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required VoidCallback onAdd,
    required void Function(int index, String value) onEdit,
    required void Function(int index, String value) onDisable,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                ),
                IconButton(
                  tooltip: 'Agregar a $title',
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'No hay opciones agregadas para este grupo.',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            )
          else
            for (int i = 0; i < options.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            options[i]['title'] ?? '',
                            style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w500),
                          ),
                          if (options[i]['isDefault'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Por defecto',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar opción',
                      icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.slate),
                      onPressed: () => onEdit(i, options[i]['title'] ?? ''),
                    ),
                    IconButton(
                      tooltip: 'Desactivar opción',
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 17, color: AppColors.danger),
                      onPressed: () => onDisable(i, options[i]['title'] ?? ''),
                    ),
                  ],
                ),
              ),
              if (i < options.length - 1)
                const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFF1F5F9)),
            ],
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-VISTA 2: AJUSTES Y REGULARIZACIONES DE ALMACÉN (SIDEBAR PERSISTENTE)
  // =========================================================================
  Widget _buildAjustesView() {
    final availableVaccines = _effectiveVaccines.isNotEmpty ? _effectiveVaccines : _sampleVaccines;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra superior de navegación con botón Volver
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _activeSubView = null),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Volver al Catálogo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ajustes y Regularizaciones de Lotes en Almacén',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              'Registro de entradas extraordinarias, mermas de red de frío y correcciones de inventario · ${widget.user.institution.name}',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Formulario de nuevo ajuste
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Registrar Nuevo Movimiento o Regularización',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: availableVaccines.any((v) => v.id == 'vac-04')
                                    ? 'vac-04'
                                    : availableVaccines.first.id,
                                decoration: const InputDecoration(labelText: 'Biológico / Vacuna'),
                                items: [
                                  for (final v in availableVaccines)
                                    DropdownMenuItem(value: v.id, child: Text(v.name)),
                                ],
                                onChanged: (_) {},
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: 'LOTE-PAI-2026-X',
                                decoration: const InputDecoration(labelText: 'Número de Lote'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: '10',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Cantidad de Frascos'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: 'conteo',
                                decoration: const InputDecoration(labelText: 'Motivo del Ajuste'),
                                items: const [
                                  DropdownMenuItem(value: 'conteo', child: Text('Ajuste por conteo físico en inventario')),
                                  DropdownMenuItem(value: 'merma', child: Text('Merma por temperatura / red de frío')),
                                  DropdownMenuItem(value: 'donacion', child: Text('Entrada extraordinaria de biológicos')),
                                  DropdownMenuItem(value: 'rotura', child: Text('Frascos descartados o averiados')),
                                ],
                                onChanged: (_) {},
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: 'Conteo de verificación mensual en almacén central.',
                                decoration: const InputDecoration(labelText: 'Observación o Justificación'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                            onPressed: () {
                              setState(() {
                                _stockAdjustmentsLog.insert(0, {
                                  'date': 'Justo ahora',
                                  'vaccine': 'Pentavalente (DPT + HB + Hib)',
                                  'lot': 'LOTE-PAI-2026-X',
                                  'type': 'Ajuste por conteo físico en inventario',
                                  'quantity': '+10 frascos',
                                  'user': widget.user.name,
                                });
                              });
                              AppSnackbar.success(
                                context,
                                'Ajuste de inventario registrado correctamente.',
                              );
                            },
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Registrar Ajuste en Almacén'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Historial de ajustes
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial de Regularizaciones Recientes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 14),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.border)),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 18, child: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 25, child: Text('Biológico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 20, child: Text('Lote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 30, child: Text('Motivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 14, child: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                ],
                              ),
                            ),
                            for (final log in _stockAdjustmentsLog)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 18, child: Text(log['date'], style: const TextStyle(fontSize: 12, color: AppColors.slate))),
                                    Expanded(flex: 25, child: Text(log['vaccine'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 20, child: Text(log['lot'], style: const TextStyle(fontSize: 12, color: AppColors.slate))),
                                    Expanded(flex: 30, child: Text(log['type'], style: const TextStyle(fontSize: 12))),
                                    Expanded(flex: 14, child: Text(log['quantity'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.hint),
            const SizedBox(height: 14),
            const Text(
              'No se encontraron biológicos que coincidan con los filtros.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Intenta ajustar el texto de búsqueda o cambia la pestaña de filtro seleccionada.',
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () {
                _searchController.clear();
                widget.controller.setQuery('');
                setState(() => _activeFilter = _CatalogFilter.all);
              },
              child: const Text('Restablecer Filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(CatalogController c) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 44),
            const SizedBox(height: 12),
            Text(c.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: c.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
