import 'package:flutter/material.dart';

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
    _tab = widget.admin && widget.initialTab == 1 ? 1 : 0;
    if (widget.online) _load();
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final isDesktop = (MediaQuery.sizeOf(context).width >= 960 || widget.embedded) && widget.admin;
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
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.admin ? 'Entregas y jornadas' : 'Mis entregas'),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(
                                  value: 0,
                                  icon: Icon(Icons.local_shipping_outlined),
                                  label: Text('Entregas'),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  icon: Icon(Icons.event_outlined),
                                  label: Text('Jornadas'),
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
                            padding: const EdgeInsets.all(24),
                            children: [
                              _heading(context),
                              const SizedBox(height: 24),
                              if (_refreshing) const LinearProgressIndicator(),
                              if (_error != null) ...[
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                jornadas
                    ? 'Organiza una jornada'
                    : widget.admin
                    ? 'Entrega vacunas'
                    : 'Mis entregas',
                style: Theme.of(context).textTheme.headlineSmall,
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
        const SizedBox(height: 8),
        Text(
          jornadas
              ? 'Define lugar y fecha, elige al equipo y asigna vacunas a cada vacunador.'
              : widget.admin
              ? 'Elige un vacunador y los frascos que recibirá. No necesitas crear una jornada.'
              : 'Confirma los frascos que recibiste físicamente.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _blocked || _error != null
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
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(
            widget.admin ? 'Custodia y cierre' : 'Mi custodia y conteos',
          ),
        ),
        if (widget.admin && widget.canWrite) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
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
            icon: const Icon(Icons.add),
            label: Text(jornadas ? 'Nueva jornada' : 'Nueva entrega'),
          ),
        ],
      ],
    );
  }

  List<Widget> _campaigns() => [
    Text(
      'Jornadas registradas',
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 8),
    if (_campaignRecords.isEmpty)
      const DeliveryEmptyState(
        title: 'Aún no hay jornadas',
        message: 'Crea una jornada para organizar lugar, fechas y equipo. Las entregas se preparan dentro de ella.',
      ),
    for (final campaign in _campaignRecords)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${campaign['name']}'),
        subtitle: Text(
          '${campaign['location']} · ${campaignDates(campaign)}\n${campaign['status'] == 'ACTIVE' ? 'Activa' : 'Finalizada'}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
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
      ),
  ];

  List<Widget> _deliveries() => [
    Text(
      'Entregas registradas',
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 8),
    if (_assignments.isEmpty)
      DeliveryEmptyState(
        title: 'Aún no hay entregas',
        message: widget.admin
            ? 'Empieza con Nueva entrega. Si es para una jornada, abre esa jornada y asigna desde su equipo.'
            : 'Las vacunas que te entreguen aparecerán aquí.',
      ),
    for (final a in _assignments)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          widget.admin
              ? '${_names[a['vaccinatorId']] ?? 'Vacunador por verificar'} · ${a['vaccineName']}'
              : '${a['vaccineName']} · ${a['lotNumber']}',
        ),
        subtitle: Text(
          '${a['vialCount']} frascos · ${deliveryStatus(a['status'])}\n${a['campaignName'] ?? 'Entrega directa · Sin jornada'}',
        ),
        isThreeLine: true,
        trailing:
            !widget.admin &&
                (a['status'] == 'IN_TRANSIT' ||
                    a['status'] == 'PARTIALLY_RECEIVED')
            ? TextButton(
                onPressed: _blocked
                    ? null
                    : () => _open(
                        ReceiptFormPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignment: a,
                        ),
                      ),
                child: const Text('Recibir'),
              )
            : const Icon(Icons.chevron_right),
        onTap: _blocked ? null : () => _details(a),
      ),
    if (_events.isNotEmpty) ...[
      const Divider(height: 32),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Devoluciones y novedades'),
        subtitle: Text('${_events.length} registradas'),
        children: [
          for (final event in _events)
            ListTile(
              title: Text('${event['vaccineName']} · ${event['lotNumber']}'),
              subtitle: Text(
                '${event['vialCount']} frascos · ${custodyEventStatus(event['status'])}',
              ),
              trailing:
                  widget.admin &&
                      widget.canWrite &&
                      event['status'] == 'RETURN_PENDING'
                  ? TextButton(
                      onPressed: _blocked
                          ? null
                          : () => _open(
                              CustodyEventFormPage(
                                controller: widget.controller,
                                institutionId: widget.institutionId,
                                record: event,
                                confirmation: true,
                              ),
                            ),
                      child: const Text('Revisar'),
                    )
                  : null,
            ),
        ],
      ),
    ],
  ];
}
