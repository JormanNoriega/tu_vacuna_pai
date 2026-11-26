import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'inventory_controller.dart';
import 'campaign_form_page.dart';
import 'campaign_detail_page.dart';
import 'delivery_form_page.dart';
import 'delivery_detail_page.dart';
import 'delivery_ui.dart';
import 'custody_page.dart';
import 'custody_event_form_page.dart';
import 'inventory_report.dart';
import 'receipt_form_page.dart';
import 'pending_follow_ups_page.dart';
import 'widgets/admin_web_delivery_view.dart';

// THESIS: dos tareas explícitas, entregar a una persona u organizar una jornada.
// OWN-WORLD: Material claro, listas y jerarquía; azul reservado para acciones.
// STORY: elegir tarea, preparar entrega, consultar su detalle cuando haga falta.
// FIRST VIEWPORT: selector, acción primaria y registros; sin catálogo de lotes.
// FORM: flujo operativo fijado por el usuario; administración por divulgación.
class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.admin,
    required this.online,
    required this.canWrite,
    this.embedded = false,
    this.initialTab = 0,
    this.institutionName,
    this.initialSubAction,
    this.onSubActionHandled,
  });
  final InventoryController controller;
  final String institutionId;
  final String? institutionName;
  final bool admin;
  final bool online;
  final bool canWrite;
  final bool embedded;
  final int initialTab;
  final String? initialSubAction;
  final VoidCallback? onSubActionHandled;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  StreamSubscription<Map<String, dynamic>>? _changeSub;
  bool _reloadAfterCurrent = false;
  int _tab = 0;
  bool _refreshing = false;
  String? _error;
  final _names = <String, String>{};
  int _request = 0;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _campaignRecords = [];
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _listenChanges();
    _tab = widget.admin && widget.initialTab == 1 ? 1 : 0;
    if (widget.online) _load();
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(_changeSub?.cancel());
      _listenChanges();
    }
    if (oldWidget.institutionId != widget.institutionId ||
        oldWidget.admin != widget.admin) {
      _request++;
      _refreshing = false;
      _error = null;
      _assignments = [];
      _campaignRecords = [];
      _events = [];
      _names.clear();
      _tab = 0;
      if (widget.online) _load();
    } else if (!oldWidget.online && widget.online) {
      _load();
    }
  }

  void _listenChanges() {
    _changeSub = widget.controller.changes.listen((_) {
      if (!mounted || !widget.online) return;
      if (widget.admin && MediaQuery.sizeOf(context).width >= 960) return;
      if (_refreshing) {
        _reloadAfterCurrent = true;
      } else {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changeSub?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    if (_refreshing || !widget.online) return;
    final request = ++_request;
    final institution = widget.institutionId;
    final admin = widget.admin;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    final c = widget.controller;
    await c.load(institution, admin: admin);
    if (!mounted || request != _request) return;
    final loadError = c.error;
    final assignments = List<Map<String, dynamic>>.of(c.assignments);
    final campaigns = List<Map<String, dynamic>>.of(c.campaigns);
    final events = List<Map<String, dynamic>>.of(c.custodyEvents);
    if (loadError == null && admin) {
      await c.loadVaccinators(institution);
      if (!mounted || request != _request) return;
      for (final p in c.vaccinators) {
        _names[p['id'] as String] = '${p['fullName']}';
      }
    }
    setState(() {
      _refreshing = false;
      _assignments = assignments;
      _campaignRecords = campaigns;
      _events = events;
      // Un fallo del directorio no debe ocultar entregas ya consultadas.
      _error = loadError;
    });
    if (_reloadAfterCurrent) {
      _reloadAfterCurrent = false;
      unawaited(_load());
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted && widget.online) await _load();
  }

  Future<void> _createCampaign() async {
    final campaign = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CampaignFormPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
        ),
      ),
    );
    if (!mounted) return;
    if (campaign != null) {
      await _open(
        CampaignDetailPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          campaign: campaign,
          canWrite: widget.canWrite,
          chooseTeamOnOpen: true,
        ),
      );
    } else {
      await _load();
    }
  }

  Future<void> _shareReport() async {
    try {
      final ok = await shareInventoryReport(
        widget.controller,
        widget.institutionId,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.controller.error ?? 'No se pudo generar el informe.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir el informe.')),
        );
      }
    }
  }

  void _details(Map<String, dynamic> a) => _open(
    DeliveryDetailPage(
      controller: widget.controller,
      institutionId: widget.institutionId,
      assignment: a,
      admin: widget.admin,
      canWrite: widget.canWrite,
      vaccinatorName: _names[a['vaccinatorId']],
    ),
  );

  bool get _blocked =>
      _refreshing || widget.controller.isLoading || !widget.online;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 960 && widget.admin;
    if (isDesktop) {
      return AdminWebDeliveryView(
        controller: widget.controller,
        institutionId: widget.institutionId,
        institutionName: widget.institutionName ?? 'Institución PAI',
        canWrite: widget.canWrite,
        online: widget.online,
        initialSubAction: widget.initialSubAction,
        onSubActionHandled: widget.onSubActionHandled,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                widget.admin ? 'Entregas y jornadas' : 'Mis entregas',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
            ),
    body: !widget.online
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta función requiere conexión. Las atenciones siguen disponibles según tu autorización offline.',
              ),
            ),
          )
        : SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    children: [
                      if (widget.admin)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              style: ButtonStyle(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith<Color>((
                                        states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                    return const Color(0xFFEFF6FF);
                                  }
                                  return Colors.white;
                                }),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith<Color>((
                                        states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                    return const Color(0xFF1E60EC);
                                  }
                                  return const Color(0xFF64748B);
                                }),
                                  iconColor:
                                      WidgetStateProperty.resolveWith<Color>((
                                        states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                    return const Color(0xFF1E60EC);
                                  }
                                  return const Color(0xFF64748B);
                                }),
                                side: WidgetStateProperty.all(
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: 0,
                                    icon: Icon(
                                      Icons.local_shipping_outlined,
                                      size: 18,
                                    ),
                                  label: Text(
                                    'Entregas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 1,
                                    icon: Icon(
                                      Icons.event_note_outlined,
                                      size: 18,
                                    ),
                                  label: Text(
                                    'Jornadas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                  ),
                                ),
                              ],
                              selected: {_tab},
                              onSelectionChanged: (v) =>
                                  setState(() => _tab = v.first),
                            ),
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                100,
                              ),
                            children: [
                              _heading(context),
                              const SizedBox(height: 24),
                                if (_refreshing)
                                  const LinearProgressIndicator(),
                              if (_error != null) ...[
                                Text(
                                  _error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _refreshing ? null : _load,
                                    child: const Text('Reintentar'),
                                  ),
                                ),
                              ],
                              if (!_refreshing && _error == null)
                                if (widget.admin && _tab == 1)
                                  ..._campaigns()
                                else
                                  ..._deliveries(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
  }

  Widget _heading(BuildContext context) {
    final jornadas = widget.admin && _tab == 1;
    final titleText = jornadas
        ? 'Organiza una jornada'
        : widget.admin
        ? 'Entrega vacunas'
        : 'Mis entregas';
    final subtitleText = jornadas
        ? 'Define lugar y fecha, elige al equipo y asigna vacunas a cada vacunador.'
        : widget.admin
        ? 'Elige un vacunador y los frascos que recibirá. No necesitas crear una jornada.'
        : 'Confirma los frascos que recibiste físicamente.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titleText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (widget.admin)
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                enabled: !_blocked,
                onSelected: (value) {
                  if (value == 'csv') {
                    _shareReport();
                  } else {
                    _open(
                      PendingFollowUpsPage(
                        controller: widget.controller,
                        institutionId: widget.institutionId,
                        online: widget.online,
                        canRead: true,
                      ),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'follow',
                    child: Text('Ver seguimiento pendiente'),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: Text('Generar informe CSV'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitleText,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.slate,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _blocked || _error != null
                ? null
                : () => _open(
                    CustodyPage(
                      controller: widget.controller,
                      institutionId: widget.institutionId,
                      admin: widget.admin,
                      canWrite: widget.canWrite,
                      online: widget.online,
                    ),
                  ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
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
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
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
                          widget.admin
                              ? 'Custodia y cierre'
                              : 'Mi custodia y conteos',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.admin
                              ? 'Control de frascos en custodia y arqueo'
                              : 'Revisa tu balance de frascos y conteos físicos',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.admin && widget.canWrite) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _blocked || _error != null
                  ? null
                  : jornadas
                  ? _createCampaign
                  : () => _open(
                      DeliveryFormPage(
                        controller: widget.controller,
                        institutionId: widget.institutionId,
                      ),
                    ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                jornadas ? 'Nueva jornada' : 'Nueva entrega',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E60EC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _campaigns() => [
    Row(
      children: [
        const Text(
          'Jornadas registradas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        if (_campaignRecords.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_campaignRecords.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ],
    ),
    const SizedBox(height: 12),
    if (_campaignRecords.isEmpty)
      const DeliveryEmptyState(
        icon: Icons.event_note_outlined,
        title: 'Aún no hay jornadas',
        message: 'Crea una jornada para organizar lugar, fechas y equipo. Las entregas se preparan dentro de ella.',
      ),
    for (var i = 0; i < _campaignRecords.length; i++) ...[
      if (i > 0) const SizedBox(height: 10),
      _buildCampaignCard(_campaignRecords[i]),
    ],
  ];

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final isActive = campaign['status'] == 'ACTIVE';
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _blocked
              ? null
              : () => _open(
                  CampaignDetailPage(
                    controller: widget.controller,
                    institutionId: widget.institutionId,
                    campaign: campaign,
                    canWrite: widget.canWrite,
                  ),
                ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: isActive
                        ? const Color(0xFF059669)
                        : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${campaign['name']}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              isActive ? 'Activa' : 'Finalizada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.slate,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${campaign['location']} · ${campaignDates(campaign)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.slate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _deliveries() => [
    Row(
      children: [
        const Text(
          'Entregas registradas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        if (_assignments.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_assignments.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ],
    ),
    const SizedBox(height: 12),
    if (_assignments.isEmpty)
      DeliveryEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'Aún no hay entregas',
        message: widget.admin
            ? 'Empieza con Nueva entrega. Si es para una jornada, abre esa jornada y asigna desde su equipo.'
            : 'Las vacunas que te entreguen aparecerán aquí.',
      ),
    for (var i = 0; i < _assignments.length; i++) ...[
      if (i > 0) const SizedBox(height: 10),
      _buildDeliveryCard(_assignments[i]),
    ],
    if (_events.isNotEmpty) ...[
      const SizedBox(height: 24),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_return_outlined,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            title: const Text(
              'Devoluciones y novedades',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              '${_events.length} registradas',
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
            ),
            children: [
              for (var i = 0; i < _events.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_events[i]['vaccineName']} · ${_events[i]['lotNumber']}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_events[i]['vialCount']} frascos · ${custodyEventStatus(_events[i]['status'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.admin &&
                          widget.canWrite &&
                          _events[i]['status'] == 'RETURN_PENDING')
                        FilledButton.tonal(
                          onPressed: _blocked
                              ? null
                              : () => _open(
                                  CustodyEventFormPage(
                                    controller: widget.controller,
                                    institutionId: widget.institutionId,
                                    record: _events[i],
                                    confirmation: true,
                                  ),
                                ),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text('Revisar'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  ];

  Widget _buildDeliveryCard(Map<String, dynamic> a) {
    final status = a['status']?.toString();
    final isPending = status == 'IN_TRANSIT' || status == 'PARTIALLY_RECEIVED';
    final isReceived = status == 'RECEIVED';

    final (statusLabel, statusBg, statusFg, statusBorder) = switch (status) {
      'RECEIVED' => (
        'Recibida',
        const Color(0xFFECFDF5),
        const Color(0xFF047857),
        const Color(0xFFA7F3D0),
      ),
      'IN_TRANSIT' => (
        'Pendiente de recepción',
        const Color(0xFFFFFBEB),
        const Color(0xFFB45309),
        const Color(0xFFFDE68A),
      ),
      'PARTIALLY_RECEIVED' => (
        'Diferencia pendiente',
        const Color(0xFFFFF7ED),
        const Color(0xFFC2410C),
        const Color(0xFFFED7AA),
      ),
      'CLOSED_WITH_DIFFERENCE' => (
        'Diferencia resuelta',
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
        const Color(0xFFBFDBFE),
      ),
      _ => (
        deliveryStatus(status),
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        const Color(0xFFE2E8F0),
      ),
    };

    final avatarBg = isReceived
        ? const Color(0xFFECFDF5)
        : isPending
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFEFF6FF);

    final avatarFg = isReceived
        ? const Color(0xFF059669)
        : isPending
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);

    final avatarIcon = isReceived
        ? Icons.check_circle_outline_rounded
        : isPending
            ? Icons.inventory_2_outlined
            : Icons.vaccines_outlined;

    final titleText = widget.admin
        ? '${_names[a['vaccinatorId']] ?? 'Vacunador por verificar'} · ${a['vaccineName']}'
        : '${a['vaccineName']} · ${a['lotNumber']}';

    final campaignText =
        a['campaignName']?.toString() ?? 'Entrega directa · Sin jornada';

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _blocked ? null : () => _details(a),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(avatarIcon, color: avatarFg, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusBorder),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: statusFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.vaccines_rounded,
                            size: 14,
                            color: AppColors.slate,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${a['vialCount']} frascos',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_note_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              campaignText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.admin && isPending)
                      FilledButton(
                        onPressed: _blocked
                            ? null
                            : () => _open(
                                ReceiptFormPage(
                                  controller: widget.controller,
                                  institutionId: widget.institutionId,
                                  assignment: a,
                                ),
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Recibir',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
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
}
