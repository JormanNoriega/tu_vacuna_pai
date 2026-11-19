import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'custody_workflow_page.dart';
import 'delivery_ui.dart';
import 'pending_follow_ups_page.dart';

/// Bandeja por entrega: conserva procedencia, no suma entregas como saldo físico.
class CustodyPage extends StatefulWidget {
  const CustodyPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.admin,
    required this.canWrite,
    required this.online,
    this.campaignId,
  });
  final InventoryController controller;
  final String institutionId;
  final String? campaignId;
  final bool admin, canWrite, online;
  @override
  State<CustodyPage> createState() => _CustodyPageState();
}

class _CustodyPageState extends State<CustodyPage> {
  List<Map<String, dynamic>> _assignments = [];
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant CustodyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.institutionId != widget.institutionId ||
        oldWidget.admin != widget.admin ||
        oldWidget.campaignId != widget.campaignId ||
        oldWidget.online != widget.online) {
      _generation++;
      _assignments = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!widget.online) {
      setState(() {
        _loading = false;
        _assignments = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await widget.controller.load(widget.institutionId, admin: widget.admin);
    if (!mounted || generation != _generation) return;
    final error = widget.controller.error;
    final assignments = widget.controller.assignments
        .where(
          (a) =>
              widget.campaignId == null || a['campaignId'] == widget.campaignId,
        )
        .map((a) => Map<String, dynamic>.of(a))
        .toList();
    final names = <String, String>{};
    if (widget.admin && error == null) {
      await widget.controller.loadVaccinators(widget.institutionId);
      if (!mounted || generation != _generation) return;
      if (widget.controller.error == null) {
        for (final p in widget.controller.vaccinators) {
          names['${p['id']}'] = '${p['fullName']}';
        }
      }
    }
    setState(() {
      _error = error;
      _assignments = error != null
          ? []
          : assignments
                .map(
                  (a) => {
                    ...a,
                    if (widget.admin)
                      'vaccinatorName':
                          names['${a['vaccinatorId']}'] ??
                          'Vacunador ${a['vaccinatorId']}',
                  },
                )
                .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.admin ? 'Custodia y cierre' : 'Mi custodia'),
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.campaignId == null
                  ? 'Seguimiento después de entregar'
                  : 'Custodia de esta jornada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Abre una entrega para recibir, documentar conteos, vincular aplicaciones y revisar su conciliación. Las jornadas finalizadas también conservan este seguimiento.',
            ),
            const SizedBox(height: 24),
            if (widget.admin && widget.online)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PendingFollowUpsPage(
                      controller: widget.controller,
                      institutionId: widget.institutionId,
                      online: widget.online,
                      canRead: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.pending_actions),
                label: const Text('Devoluciones y correcciones por verificar'),
              ),
            if (!widget.online)
              const Text('Necesitas conexión para consultar la custodia.')
            else if (_loading)
              const LinearProgressIndicator()
            else if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ] else ...[
              if (_assignments.isEmpty)
                const Text(
                  'No hay entregas para este ámbito. No se han creado custodias ni saldos supuestos.',
                ),
              for (final a in _assignments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${widget.admin ? '${a['vaccinatorName']} · ' : ''}${a['vaccineName']} · Lote ${a['lotNumber']}',
                  ),
                  subtitle: Text(
                    '${deliveryStatus(a['status'])}\n${a['receivedVials'] ?? 0} frascos recibidos registrados · ${a['campaignName'] ?? 'Entrega directa'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustodyWorkflowPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignment: a,
                          admin: widget.admin,
                          canWrite: widget.canWrite,
                          online: widget.online,
                        ),
                      ),
                    );
                    if (mounted) await _load();
                  },
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
