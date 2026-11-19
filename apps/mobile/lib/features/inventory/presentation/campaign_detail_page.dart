import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'delivery_ui.dart';
import 'delivery_form_page.dart';
import 'delivery_detail_page.dart';
import 'campaign_team_page.dart';
import 'custody_page.dart';

/// Lugar y fecha → equipo → vacunas de cada vacunador. Nunca infiere custodia.
class CampaignDetailPage extends StatefulWidget {
  const CampaignDetailPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.campaign,
    required this.canWrite,
    this.chooseTeamOnOpen = false,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> campaign;
  final bool canWrite;
  final bool chooseTeamOnOpen;

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  late Map<String, dynamic> _campaign = widget.campaign;
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;
  String? _error;

  bool get _active => _campaign['status'] == 'ACTIVE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  Future<void> _initialize() async {
    await _load();
    if (mounted &&
        _error == null &&
        widget.chooseTeamOnOpen &&
        widget.canWrite &&
        _active) {
      await _team();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final c = widget.controller;
    await c.load(widget.institutionId, admin: true);
    if (!mounted) return;
    if (c.error != null) {
      setState(() {
        _error = c.error;
        _loading = false;
      });
      return;
    }
    for (final campaign in c.campaigns) {
      if (campaign['id'] == _campaign['id']) _campaign = campaign;
    }
    final assignments = c.assignments
        .where((a) => a['campaignId'] == _campaign['id'])
        .toList();
    final people = await c.loadCampaignParticipants(
      widget.institutionId,
      _campaign['id'] as String,
    );
    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _participants = people ?? [];
      _error = people == null
          ? c.error ?? 'No se pudo consultar el equipo.'
          : null;
      _loading = false;
    });
  }

  Future<void> _team() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => CampaignTeamPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          campaignId: _campaign['id'] as String,
          participantIds: _participants.map((p) => p['id'] as String).toSet(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _assign(Map<String, dynamic> person) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => DeliveryFormPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          campaign: _campaign,
          vaccinator: person,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _detail(Map<String, dynamic> a, String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryDetailPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          assignment: a,
          admin: true,
          canWrite: widget.canWrite,
          vaccinatorName: name,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _finish() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar jornada'),
        content: const Text(
          'Ya no podrás agregar vacunadores ni entregar más vacunas para esta jornada. Las entregas y devoluciones pendientes seguirán abiertas; no se moverán existencias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    setState(() => _loading = true);
    final ok = await widget.controller.post(
      widget.institutionId,
      'campaigns/${_campaign['id']}/finish',
      {},
    );
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      setState(() {
        _loading = false;
        _error = widget.controller.error ?? 'No se pudo finalizar la jornada.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Jornada'),
      actions: [
        if (widget.canWrite && _active)
          PopupMenuButton<String>(
            enabled: !_loading && _error == null,
            onSelected: (_) => _finish(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'finish', child: Text('Finalizar jornada')),
            ],
          ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${_campaign['name']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${_campaign['location']}')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(campaignDates(_campaign))),
              ],
            ),
            if (!_active) ...[
              const SizedBox(height: 16),
              const Text(
                'Jornada finalizada. Las entregas conservan su seguimiento.',
              ),
            ],
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _loading || _error != null
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CustodyPage(
                            controller: widget.controller,
                            institutionId: widget.institutionId,
                            campaignId: '${_campaign['id']}',
                            admin: true,
                            canWrite: widget.canWrite,
                            online: true,
                          ),
                        ),
                      );
                      if (mounted) await _load();
                    },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Ver custodia y cierre de la jornada'),
            ),
            const SizedBox(height: 24),
            Text(
              'Equipo y vacunas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Abre cada vacunador para ver sus entregas o asignarle vacunas.',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ] else ...[
              if (_participants.isEmpty)
                const DeliveryEmptyState(
                  title: 'Elige quiénes participarán',
                  message: 'Agrega vacunadores al equipo. Después asigna las vacunas y frascos a cada uno.',
                ),
              for (final person in _participants) _person(person),
              // No ocultar entregas históricas aunque ya no exista su participante.
              for (final a in _assignments.where(
                (a) => !_participants.any((p) => p['id'] == a['vaccinatorId']),
              ))
                ListTile(
                  title: Text(
                    '${a['vaccineName']} · ${a['vialCount']} frascos',
                  ),
                  subtitle: const Text(
                    'Vacunador no incluido en el equipo consultado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _detail(a, 'Vacunador por verificar'),
                ),
              if (widget.canWrite && _active) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _team,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(
                      _participants.isEmpty
                          ? 'Elegir vacunadores'
                          : 'Agregar vacunadores',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );

  Widget _person(Map<String, dynamic> person) {
    final deliveries = _assignments
        .where((a) => a['vaccinatorId'] == person['id'])
        .toList();
    return ExpansionTile(
      key: PageStorageKey('team-${person['id']}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      title: Text('${person['name']}'),
      subtitle: Text(
        deliveries.isEmpty
            ? 'Sin vacunas asignadas'
            : '${deliveries.length} entregas registradas',
      ),
      children: [
        for (final a in deliveries)
          ListTile(
            title: Text('${a['vaccineName']} · ${a['vialCount']} frascos'),
            subtitle: Text(
              'Lote ${a['lotNumber']} · ${deliveryStatus(a['status'])}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _detail(a, '${person['name']}'),
          ),
        if (widget.canWrite && _active)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _assign(person),
              icon: const Icon(Icons.add),
              label: const Text('Asignar vacunas'),
            ),
          ),
      ],
    );
  }
}
