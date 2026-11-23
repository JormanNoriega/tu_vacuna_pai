import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/clinical_components.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/presentation/widgets/shimmer_loading.dart';
import '../../../../core/utils/document_input.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../auth/domain/entities/session_restore_result.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/presentation/patient_detail_controller.dart';
import '../../../patients/presentation/pages/patient_detail_page.dart';
import '../../domain/entities/attention.dart';
import '../history_controller.dart';
import '../widgets/admin_web_history_view.dart';
import '../../../reports/presentation/export_report_controller.dart';

/// Historial de atenciones de un paciente (busqueda por documento).
class HistorialPage extends StatefulWidget {
  const HistorialPage({
    required this.controller,
    required this.patientDetailController,
    required this.offline,
    this.institutionId = '',
    this.institutionName,
    this.userId = '',
    this.isAdmin = false,
    this.exportReportController,
    this.initialSubAction,
    this.onSubActionHandled,
    super.key,
  });

  final HistoryController controller;
  final PatientDetailController patientDetailController;
  final OfflineAccess offline;
  final String institutionId;
  final String? institutionName;
  final String userId;
  final bool isAdmin;
  final ExportReportController? exportReportController;
  final String? initialSubAction;
  final VoidCallback? onSubActionHandled;

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final _number = TextEditingController();
  final _scrollController = ScrollController(keepScrollOffset: false);
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
    _scrollController.dispose();
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 960 && widget.isAdmin;
    if (isDesktop) {
      return AdminWebHistoryView(
        controller: widget.controller,
        patientDetailController: widget.patientDetailController,
        offline: widget.offline,
        institutionId: widget.institutionId,
        institutionName: widget.institutionName ?? 'Institución PAI',
        userId: widget.userId,
        isAdmin: widget.isAdmin,
        exportReportController: widget.exportReportController,
        initialSubAction: widget.initialSubAction,
        onSubActionHandled: widget.onSubActionHandled,
      );
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final patient = controller.patient;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          radius: const Radius.circular(8),
          thickness: 3,
          child: ListView(
            key: const PageStorageKey<String>('vaccinator-attention-history'),
            controller: _scrollController,
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Text('Historial', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Busca un paciente específico o consulta las atenciones recientes.',
                style: TextStyle(color: AppColors.slate, height: 1.4),
              ),
              const SizedBox(height: 16),
              // Buscador por documento siempre arriba
              _buildSearchBox(context, controller),
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
              // Abajo: Resultados del paciente buscado O Historial de todos los registros
              if (_searching)
                _skeletonHistory()
              else if (patient != null)
                _buildPatientResults(context, controller, patient)
              else
                _buildGeneralHistory(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBox(BuildContext context, HistoryController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buscar paciente específico',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Digita el documento de identidad para ver sus dosis.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _docType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de documento'),
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
            decoration: InputDecoration(
              labelText: 'Número de documento',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              suffixIcon: _number.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _number.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (!_searching) _search();
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text('Buscar historial'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientResults(
    BuildContext context,
    HistoryController controller,
    Patient patient,
  ) {
    return Column(
      key: const ValueKey('history_content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RESULTADO DE BÚSQUEDA',
              style: AppTextStyles.overline.copyWith(color: AppColors.primary),
            ),
            TextButton.icon(
              onPressed: () {
                _number.clear();
                controller.resetResults();
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Limpiar búsqueda'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
              style: AppTextStyles.overline.copyWith(color: AppColors.primary),
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
            message: 'Este paciente aun no tiene dosis aplicadas.',
          )
        else
          for (var i = 0; i < controller.history.length; i++)
            _AttentionTimelineItem(
              attention: controller.history[i],
              isLast: i == controller.history.length - 1,
            ),
      ],
    );
  }

  Widget _buildGeneralHistory(BuildContext context) {
    if (widget.institutionId.isNotEmpty && widget.userId.isNotEmpty) {
      return _RecentHistory(
        key: const ValueKey('recent_history_section'),
        controller: widget.controller,
        institutionId: widget.institutionId,
        userId: widget.userId,
        isAdmin: widget.isAdmin,
        patientDetailController: widget.patientDetailController,
        offline: widget.offline,
      );
    }
    return const EmptyState(
      key: ValueKey('empty_prompt'),
      icon: Icons.folder_shared_outlined,
      title: 'Busca un paciente',
      message:
          'Ingresa un documento para ver sus atenciones y dosis aplicadas.',
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

String _getInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'P';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

String _formatTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Ahora';
  } else if (difference.inMinutes < 60) {
    return 'Hace ${difference.inMinutes}m';
  } else if (difference.inHours < 24) {
    return 'Hace ${difference.inHours}h';
  } else if (difference.inDays < 7) {
    return 'Hace ${difference.inDays}d';
  } else {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    return '$day/$month/${timestamp.year}';
  }
}

class _RecentHistory extends StatefulWidget {
  const _RecentHistory({
    required this.controller,
    required this.institutionId,
    required this.userId,
    required this.isAdmin,
    this.patientDetailController,
    this.offline,
    super.key,
  });

  final HistoryController controller;
  final String institutionId;
  final String userId;
  final bool isAdmin;
  final PatientDetailController? patientDetailController;
  final OfflineAccess? offline;

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
      start: today.subtract(const Duration(days: 364)),
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
        offline: widget.offline?.status != SessionStatus.signedIn,
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
        // Cabecera: Título y botón refrescar
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial de registros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Color(0xFF2563EB),
              ),
              onPressed: _loading ? null : () => _load(_page),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Selector de rango en fila dedicada para evitar cualquier desborde horizontal (overflow)
        InkWell(
          key: const ValueKey('history-date-range'),
          onTap: _loading ? null : _chooseRange,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rango: ${_date(_range.start)} – ${_date(_range.end)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_calendar_outlined,
                  size: 16,
                  color: AppColors.slate,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_loading)
          _skeletonRecentCards()
        else if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _load(_page),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_items.isEmpty)
          Container(
            key: const ValueKey('records_empty'),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            ),
            child: const Center(
              child: Text(
                'No hay registros en este período',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else ...[
          // Lista de cards con estilo exacto de Últimos Registros
          Column(
            key: const ValueKey('records_list'),
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildHistoryCard(context, _items[i]),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Controles de Paginación
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 380) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Anterior',
                      onPressed: _page > 0 ? () => _load(_page - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Página ${_page + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: _hasNext ? () => _load(_page + 1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _page > 0 ? () => _load(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Anterior'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Página ${_page + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _hasNext ? () => _load(_page + 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Siguiente'),
                    iconAlignment: IconAlignment.end,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
    final patientId = item['patientId']?.toString();
    final patientName = '${item['patientName'] ?? 'Paciente'}';
    final document = '${item['document'] ?? ''}';
    final doses = (item['doses'] as List? ?? []);
    final rawDate = item['date']?.toString();
    final parsedDate = DateTime.tryParse(rawDate ?? '') ?? DateTime.now();

    final vaccineNames = doses
        .whereType<Map>()
        .map((dose) => _displayVaccineName(dose['vaccine']))
        .where((name) => name != null)
        .cast<String>()
        .toSet();
    final vaccineName = vaccineNames.isEmpty
        ? 'Atención de vacunación'
        : vaccineNames.join(', ');

    final subtitle = document.isNotEmpty
        ? '$vaccineName  ·  $document'
        : vaccineName;

    final canNavigate =
        patientId != null &&
        patientId.isNotEmpty &&
        widget.patientDetailController != null &&
        widget.offline != null;

    return Material(
      key: ValueKey('history-record-${item['id'] ?? patientId ?? patientName}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: canNavigate
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientDetailPage(
                    controller: widget.patientDetailController!,
                    offline: widget.offline!,
                    patientId: patientId,
                  ),
                ),
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimeAgo(parsedDate.toLocal()),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
              if (canNavigate) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _displayVaccineName(Object? rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty ||
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      return null;
    }
    return value;
  }

  Widget _skeletonRecentCards() {
    return ShimmerLoading(
      key: const ValueKey('records_skeleton'),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              ),
              child: ShimmerEffect(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 90,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _getInitials(patientName),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
                    patientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: AppColors.slate,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$documentType $documentNumber',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onOpenProfile,
          icon: const Icon(Icons.badge_outlined, size: 18),
          label: const Text('Ver ficha del paciente'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
