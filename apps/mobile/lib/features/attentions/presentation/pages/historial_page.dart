import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/clinical_components.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/utils/document_input.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../patients/presentation/patient_detail_controller.dart';
import '../../../patients/presentation/pages/patient_detail_page.dart';
import '../../domain/entities/attention.dart';
import '../history_controller.dart';

/// Historial de atenciones de un paciente (busqueda por documento).
class HistorialPage extends StatefulWidget {
  const HistorialPage({
    required this.controller,
    required this.patientDetailController,
    required this.offline,
    this.institutionId = '',
    this.userId = '',
    this.isAdmin = false,
    super.key,
  });

  final HistoryController controller;
  final PatientDetailController patientDetailController;
  final OfflineAccess offline;
  final String institutionId;
  final String userId;
  final bool isAdmin;

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final _number = TextEditingController();
  String _docType = 'CC';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Entra en blanco (sin resultados previos) pero conserva el catalogo de
    // tipos de documento: no bloquea la busqueda mientras se precarga.
    widget.controller.resetResults();
    widget.controller.loadDocumentTypes();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  /// Tipo de identificacion con etiqueta "CODIGO - Nombre" (ej.
  /// "CC - Cedula de Ciudadania"), desde el catalogo `document_type`.
  List<DropdownMenuItem<String>> _documentTypeItems() {
    final options = widget.controller.documentTypes;
    final list = options.isEmpty ? documentTypeFallback : options;
    return [
      for (final option in list)
        DropdownMenuItem(
          value: option.code,
          child: Text('${option.code} - ${option.label}'),
        ),
    ];
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final number = _number.text.trim();
    if (number.isEmpty) {
      AppSnackbar.warning(context, 'Ingresa el numero de documento.');
      return;
    }
    setState(() => _searching = true);
    await widget.controller.loadHistory(
      documentType: _docType,
      documentNumber: number,
    );
    if (!mounted) return;
    setState(() => _searching = false);
    if (widget.controller.patient == null) {
      AppSnackbar.warning(
        context,
        'No se encontro un paciente con ese documento.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final patient = controller.patient;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Consulta las atenciones recientes o busca un paciente.',
              style: TextStyle(color: AppColors.slate, height: 1.4),
            ),
            if (widget.institutionId.isNotEmpty &&
                widget.userId.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RecentHistory(
                controller: widget.controller,
                institutionId: widget.institutionId,
                userId: widget.userId,
                isAdmin: widget.isAdmin,
              ),
              const SizedBox(height: 24),
              Text(
                'Buscar por paciente',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _docType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento',
                    ),
                    items: _documentTypeItems(),
                    onChanged: (value) => setState(() {
                      if (value != _docType) _number.clear();
                      _docType = value ?? 'CC';
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _number,
                    keyboardType: documentKeyboardType(_docType),
                    inputFormatters: documentInputFormatters(_docType),
                    decoration: const InputDecoration(labelText: 'Documento'),
                    onSubmitted: (_) {
                      if (!_searching) _search();
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('Buscar historial'),
                  ),
                ],
              ),
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              child: _searching
                  ? _skeletonHistory()
                  : patient == null
                  ? const EmptyState(
                      key: ValueKey('empty_prompt'),
                      icon: Icons.folder_shared_outlined,
                      title: 'Busca un paciente',
                      message:
                          'Ingresa un documento para ver sus atenciones y dosis '
                          'aplicadas.',
                    )
                  : Column(
                      key: const ValueKey('history_content'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PatientHeader(
                          patientName: patient.fullName,
                          documentType: patient.documentType,
                          documentNumber: patient.documentNumber,
                          onOpenProfile: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PatientDetailPage(
                                controller: widget.patientDetailController,
                                offline: widget.offline,
                                patientId: patient.id,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'ATENCIONES',
                              style: AppTextStyles.overline.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            if (controller.history.isNotEmpty)
                              StatusPill(
                                label: '${controller.history.length}',
                                tone: StatusTone.neutral,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (controller.history.isEmpty)
                          const EmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'Sin atenciones registradas',
                            message:
                                'Este paciente aun no tiene dosis aplicadas.',
                          )
                        else
                          for (var i = 0; i < controller.history.length; i++)
                            _AttentionTimelineItem(
                              attention: controller.history[i],
                              isLast: i == controller.history.length - 1,
                            ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _skeletonHistory() {
    return ShimmerLoading(
      key: const ValueKey('history_skeleton'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _skeletonPatientHeader(),
          const SizedBox(height: 20),
          ShimmerEffect(
            child: Row(
              children: [
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
          const SizedBox(height: 12),
          _skeletonTimelineItem(isLast: false),
          _skeletonTimelineItem(isLast: true),
        ],
      ),
    );
  }

  Widget _skeletonPatientHeader() => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.all(16),
    child: ShimmerEffect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
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
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _skeletonTimelineItem({required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: ShimmerEffect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 90,
                            height: 15,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 60,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 110,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 130,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHistory extends StatefulWidget {
  const _RecentHistory({
    required this.controller,
    required this.institutionId,
    required this.userId,
    required this.isAdmin,
  });

  final HistoryController controller;
  final String institutionId;
  final String userId;
  final bool isAdmin;

  @override
  State<_RecentHistory> createState() => _RecentHistoryState();
}

class _RecentHistoryState extends State<_RecentHistory> {
  late DateTimeRange _range;
  List<Map<String, dynamic>> _items = [];
  int _page = 0;
  int _request = 0;
  bool _loading = false;
  bool _hasNext = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
    _load(0);
  }

  Future<void> _load(int page) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _hasNext = false;
      _page = page;
    });
    try {
      final end = DateTime(
        _range.end.year,
        _range.end.month,
        _range.end.day + 1,
      );
      final result = await widget.controller.recentPage(
        admin: widget.isAdmin,
        institutionId: widget.institutionId,
        userId: widget.userId,
        from: _range.start,
        to: end,
        page: page,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = (result['items'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _hasNext = result['hasNext'] == true;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = widget.isAdmin
            ? 'No se pudo consultar el servidor. Verifica tu conexión e intenta de nuevo.'
            : 'No se pudo consultar el historial local. Intenta de nuevo.',
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Selecciona el rango de atenciones',
    );
    if (!mounted || selected == null) return;
    if (selected.end.difference(selected.start).inDays > 365) {
      AppSnackbar.warning(context, 'Selecciona un rango máximo de 366 días.');
      return;
    }
    setState(() => _range = selected);
    await _load(0);
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Atenciones recientes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          widget.isAdmin
              ? 'Atenciones sincronizadas de la institución.'
              : 'Tus atenciones guardadas en este dispositivo.',
          style: const TextStyle(color: AppColors.slate),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _chooseRange,
          icon: const Icon(Icons.date_range),
          label: Text('${_date(_range.start)} – ${_date(_range.end)}'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _loading ? null : () => _load(_page),
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          TextButton(
            onPressed: () => _load(_page),
            child: const Text('Reintentar'),
          ),
        ] else if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No hay atenciones en este rango de fechas.'),
          )
        else
          for (var index = 0; index < _items.length; index++) ...[
            if (DateTime.tryParse('${_items[index]['date']}')
                case final parsed?)
              if (index == 0 ||
                  DateUtils.dateOnly(parsed.toLocal()) !=
                      DateUtils.dateOnly(
                        DateTime.parse('${_items[index - 1]['date']}')
                            .toLocal(),
                      )) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    _date(parsed.toLocal()),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_items[index]['patientName'] ?? 'Paciente'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text('${_items[index]['document'] ?? ''}'),
                    Text(
                      widget.isAdmin
                          ? 'Atendió: ${_items[index]['professionalName'] ?? 'No disponible'}'
                          : 'Atendió: tú',
                    ),
                    Text(
                      'Estado: ${switch (_items[index]['status']) {
                        'COMPLETED' => 'Completada',
                        'CANCELLED' => 'Anulada',
                        'DRAFT' => 'Borrador',
                        'IN_PROGRESS' => 'En curso',
                        _ => _items[index]['status'] ?? 'No disponible',
                      }}',
                    ),
                    if (_items[index]['consecutive'] != null)
                      Text('Consecutivo: ${_items[index]['consecutive']}'),
                    if ((_items[index]['observations'] as String?)
                            ?.isNotEmpty ==
                        true)
                      Text('Observaciones: ${_items[index]['observations']}'),
                    if (!widget.isAdmin && _items[index]['syncState'] != null)
                      Text('Sincronización: ${switch (_items[index]['syncState']) {
                        'SYNCED' => 'Sincronizada',
                        'PENDING_SYNC' || 'LOCAL_ONLY' => 'Pendiente',
                        'SYNCING' => 'En curso',
                        'FAILED' || 'QUARANTINED' => 'Requiere revisión',
                        _ => 'No disponible',
                      }}'),
                    for (final dose in (_items[index]['doses'] as List? ?? []))
                      Text(
                        '• ${dose['vaccine'] ?? 'Vacuna'}'
                        '${dose['label'] == null ? '' : ' · ${dose['label']}'}'
                        '${dose['lot'] == null ? '' : ' · Lote ${dose['lot']}'}'
                        '${dose['status'] == 'CANCELLED' ? ' · Anulada' : ''}',
                      ),
                  ],
                ),
              ),
            ),
          ],
        if (!_loading)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _page > 0 ? () => _load(_page - 1) : null,
                child: const Text('Anterior'),
              ),
              Text('Página ${_page + 1}'),
              TextButton(
                onPressed: _hasNext ? () => _load(_page + 1) : null,
                child: const Text('Siguiente'),
              ),
            ],
          ),
      ],
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.patientName,
    required this.documentType,
    required this.documentNumber,
    required this.onOpenProfile,
  });

  final String patientName;
  final String documentType;
  final String documentNumber;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IdentityStrip(
          documentType: documentType,
          documentNumber: documentNumber,
          name: patientName,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenProfile,
          icon: const Icon(Icons.badge_outlined, size: 18),
          label: const Text('Ver ficha del paciente'),
        ),
      ],
    ),
  );
}

/// Linea de tiempo clinica: cada atencion es un nodo sobre un riel vertical.
class _AttentionTimelineItem extends StatelessWidget {
  const _AttentionTimelineItem({required this.attention, required this.isLast});

  final Attention attention;
  final bool isLast;

  StatusTone get _tone => switch (attention.status) {
    'COMPLETED' => StatusTone.applied,
    'CANCELLED' => StatusTone.cancelled,
    _ => StatusTone.draft,
  };

  Color get _nodeColor => switch (attention.status) {
    'COMPLETED' => AppColors.success,
    'CANCELLED' => AppColors.danger,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MonoText(
                            _formatDate(attention.attentionDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusPill(label: attention.statusLabel, tone: _tone),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attention.doses.length} dosis'
                      '${attention.consecutive != null ? '  ·  Consecutivo ${attention.consecutive}' : ''}',
                      style: const TextStyle(
                        color: AppColors.hint,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    for (final dose in attention.doses) _DoseLine(dose: dose),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine({required this.dose});

  final AppliedDose dose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dose.isCancelled ? AppColors.danger : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.vaccineNameSnapshot,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${dose.doseLabelSnapshot}'
                  '${(dose.lotNumber ?? '').isNotEmpty ? '  ·  Lote ${dose.lotNumber}' : ''}',
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (dose.isCancelled)
            const StatusPill(label: 'Anulada', tone: StatusTone.cancelled),
        ],
      ),
    );
  }
}
