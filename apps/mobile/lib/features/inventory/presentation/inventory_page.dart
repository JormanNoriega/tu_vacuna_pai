import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'inventory_form_page.dart';
import 'campaign_form_page.dart';
import 'custody_event_form_page.dart';
import 'inventory_report.dart';
import 'receipt_form_page.dart';
import 'difference_resolution_page.dart';
import 'pending_follow_ups_page.dart';
import 'historical_custody_review_page.dart';
import 'delivery_conciliation_page.dart';

/// Inventario fisico online; el catalogo clinico sigue siendo independiente.
class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.admin,
    required this.online,
    required this.canWrite,
    this.embedded = false,
  });
  final InventoryController controller;
  final String institutionId;
  final bool admin;
  final bool online;
  final bool canWrite;
  final bool embedded;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int _tab = 0;
  @override
  void initState() {
    super.initState();
    if (widget.online) _load();
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.online && widget.online) _load();
  }

  Future<void> _load() =>
      widget.controller.load(widget.institutionId, admin: widget.admin);

  Future<void> _openForm({
    required bool isLot,
    Map<String, dynamic>? lot,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InventoryFormPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          isLot: isLot,
          lot: lot,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openCustodyForm(
    Map<String, dynamic> record, {
    required bool confirmation,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustodyEventFormPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          record: record,
          confirmation: confirmation,
        ),
      ),
    );
    if (mounted) await _load();
  }

  String _eventStatus(String? status) => switch (status) {
    'RETURN_PENDING' => 'Devolución pendiente de recepción',
    'RETURN_AVAILABLE' => 'Recibida y reincorporada',
    'RETURN_QUARANTINED' => 'Recibida en cuarentena',
    'INCIDENT_LOST' => 'Pérdida declarada',
    'INCIDENT_QUARANTINED' => 'Inmovilización declarada',
    _ => 'Estado no reconocido',
  };

  String _assignmentStatus(String? status) => switch (status) {
    'RECEIVED' => 'Recibida',
    'IN_TRANSIT' => 'En tránsito',
    'PARTIALLY_RECEIVED' => 'Diferencia pendiente',
    'CLOSED_WITH_DIFFERENCE' => 'Entrega cerrada con diferencia',
    _ => 'Estado no reconocido',
  };

  Future<void> _reviewDifference(Map<String, dynamic> assignment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DifferenceResolutionPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          assignment: assignment,
          canWrite: widget.canWrite,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _receive(Map<String, dynamic> assignment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptFormPage(
          controller: widget.controller,
          institutionId: widget.institutionId,
          assignment: assignment,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _finishCampaign(Map<String, dynamic> campaign) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar jornada'),
        content: const Text(
          'Finalizar la jornada no devuelve vacunas ni cierra las entregas o custodias pendientes.',
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
    if (confirm != true || !mounted) return;
    if (await widget.controller.post(
      widget.institutionId,
      'campaigns/${campaign['id']}/finish',
      {},
    )) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
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
        : ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final c = widget.controller;
              return Column(
                children: [
                  if (widget.admin)
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Entregas')),
                        ButtonSegment(value: 1, label: Text('Jornadas')),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (value) =>
                          setState(() => _tab = value.first),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            widget.admin
                                ? 'Entrega frascos a vacunadores, organiza jornadas y revisa devoluciones. Para agregar existencias, entra a la configuración de cada vacuna.'
                                : 'Consulta los frascos que te entregaron y confirma solo los que recibiste físicamente. Requiere conexión.',
                          ),
                          if (c.isLoading) const LinearProgressIndicator(),
                          if (c.error != null)
                            ListTile(
                              title: Text(c.error!),
                              trailing: TextButton(
                                onPressed: _load,
                                child: const Text('Reintentar'),
                              ),
                            ),
                          if (widget.admin && _tab == 0) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: c.isLoading
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => PendingFollowUpsPage(
                                            controller: c,
                                            institutionId: widget.institutionId,
                                            online: widget.online,
                                            canRead: widget.admin,
                                          ),
                                        ),
                                      ),
                                icon: const Icon(Icons.fact_check_outlined),
                                label: const Text('Ver seguimiento pendiente'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: c.isLoading ? null : _shareReport,
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('Generar informe CSV'),
                              ),
                            ),
                            Text(
                              'Incluye existencias, movimientos, entregas, jornadas y novedades.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (widget.admin && _tab == 1) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Jornadas',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Opcional: organiza una actividad de vacunación. Crear una jornada no mueve frascos.',
                            ),
                            if (widget.canWrite)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: c.isLoading
                                      ? null
                                      : () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<bool>(
                                              builder: (_) => CampaignFormPage(
                                                controller: c,
                                                institutionId:
                                                    widget.institutionId,
                                              ),
                                            ),
                                          );
                                          if (mounted) await _load();
                                        },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Nueva jornada'),
                                ),
                              ),
                            if (!c.isLoading &&
                                c.error == null &&
                                c.campaigns.isEmpty)
                              const ListTile(
                                title: Text('No hay jornadas registradas.'),
                              ),
                            for (final campaign in c.campaigns)
                              ListTile(
                                title: Text('${campaign['name']}'),
                                subtitle: Text(
                                  '${campaign['location']} · ${campaign['startsOn']} — ${campaign['endsOn']}\n${campaign['status'] == 'ACTIVE' ? 'Activa' : 'Finalizada'}',
                                ),
                                isThreeLine: true,
                                trailing:
                                    widget.canWrite &&
                                        campaign['status'] == 'ACTIVE'
                                    ? TextButton(
                                        onPressed: c.isLoading
                                            ? null
                                            : () => _finishCampaign(campaign),
                                        child: const Text('Finalizar'),
                                      )
                                    : null,
                              ),
                          ],
                          if (widget.admin && _tab == 0) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Lotes con saldo en depósito',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Elige un lote para entregar frascos a un vacunador. Verifica su vencimiento y conservación.',
                            ),
                            if (!c.isLoading &&
                                c.error == null &&
                                c.lots.isEmpty)
                              const ListTile(
                                title: Text(
                                  'Aún no hay lotes. Agrega existencias desde la configuración de la vacuna.',
                                ),
                              ),
                            for (final lot in c.lots)
                              ListTile(
                                title: Text(
                                  '${lot['vaccineName']} · ${lot['lotNumber']}',
                                ),
                                subtitle: Text(
                                  '${lot['manufacturer']} · Vence ${lot['expiresOn']}\n${lot['availableVials']} frascos en depósito',
                                ),
                                isThreeLine: true,
                                trailing: widget.canWrite
                                    ? TextButton(
                                        onPressed: c.isLoading
                                            ? null
                                            : () => _openForm(
                                                isLot: false,
                                                lot: lot,
                                              ),
                                        child: const Text('Entregar'),
                                      )
                                    : null,
                              ),
                          ],
                          if (_tab == 0) ...[
                            const SizedBox(height: 20),
                            Text(
                              widget.admin ? 'Entregas' : 'Mis entregas',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              widget.admin
                                  ? 'Frascos entregados a vacunadores y su estado de recepción.'
                                  : 'Revisa y confirma los frascos recibidos.',
                            ),
                            if (!c.isLoading &&
                                c.error == null &&
                                c.assignments.isEmpty)
                              const ListTile(
                                title: Text('No hay entregas registradas.'),
                              ),
                            for (final a in c.assignments)
                              ListTile(
                                title: Text(
                                  '${a['vaccineName']} · ${a['lotNumber']}',
                                ),
                                subtitle: Text(
                                  '${a['vialCount']} frascos · ${_assignmentStatus(a['status'] as String?)}${a['status'] == 'PARTIALLY_RECEIVED' || a['status'] == 'CLOSED_WITH_DIFFERENCE' ? '\nRecibidos: ${a['receivedVials']} · Resueltos: ${a['resolvedVials'] ?? 0} · Pendientes: ${(a['vialCount'] as num).toInt() - (a['receivedVials'] as num).toInt() - ((a['resolvedVials'] as num?)?.toInt() ?? 0)}${a['differenceNote'] != null ? '\nMotivo: ${a['differenceNote']}' : ''}' : ''}${a['campaignName'] != null ? '\nJornada: ${a['campaignName']}' : ''}',
                                ),
                                trailing: widget.admin
                                    ? PopupMenuButton<String>(
                                        tooltip: 'Opciones de la entrega',
                                        enabled: !c.isLoading,
                                        onSelected: (value) {
                                          if (value == 'history') {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    HistoricalCustodyReviewPage(
                                                      controller: c,
                                                      institutionId:
                                                          widget.institutionId,
                                                      assignmentId:
                                                          a['id'] as String,
                                                      online: widget.online,
                                                      canRead: widget.admin,
                                                    ),
                                              ),
                                            );
                                          } else if (value == 'conciliation') {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    DeliveryConciliationPage(
                                                      controller: c,
                                                      institutionId:
                                                          widget.institutionId,
                                                      assignmentId:
                                                          a['id'] as String,
                                                      online: widget.online,
                                                      canRead: widget.admin,
                                                    ),
                                              ),
                                            );
                                          } else if (value == 'difference') {
                                            _reviewDifference(a);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'conciliation',
                                            child: Text('Ver conciliación'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'history',
                                            child: Text('Ver historial'),
                                          ),
                                          if (a['status'] ==
                                                  'PARTIALLY_RECEIVED' ||
                                              a['status'] ==
                                                  'CLOSED_WITH_DIFFERENCE')
                                            const PopupMenuItem(
                                              value: 'difference',
                                              child: Text('Revisar diferencia'),
                                            ),
                                        ],
                                      )
                                    : !widget.admin &&
                                          a['status'] == 'PARTIALLY_RECEIVED' &&
                                          (a['receivedVials'] as num) > 0
                                    ? PopupMenuButton<String>(
                                        tooltip: 'Acciones de la entrega',
                                        enabled: !c.isLoading,
                                        onSelected: (value) {
                                          if (value == 'receive') {
                                            _receive(a);
                                          } else {
                                            _openCustodyForm(
                                              a,
                                              confirmation: false,
                                            );
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'receive',
                                            child: Text(
                                              'Recepción complementaria',
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'declare',
                                            child: Text(
                                              'Declarar devolución o novedad',
                                            ),
                                          ),
                                        ],
                                      )
                                    : !widget.admin &&
                                          (a['status'] == 'IN_TRANSIT' ||
                                              a['status'] ==
                                                  'PARTIALLY_RECEIVED')
                                    ? TextButton(
                                        onPressed: c.isLoading
                                            ? null
                                            : () => _receive(a),
                                        child: const Text('Recibir'),
                                      )
                                    : !widget.admin &&
                                          (a['status'] == 'RECEIVED' ||
                                              (a['status'] ==
                                                      'CLOSED_WITH_DIFFERENCE' &&
                                                  (a['receivedVials'] as num) >
                                                      0))
                                    ? TextButton(
                                        onPressed: c.isLoading
                                            ? null
                                            : () => _openCustodyForm(
                                                a,
                                                confirmation: false,
                                              ),
                                        child: const Text('Declarar'),
                                      )
                                    : null,
                              ),
                            const SizedBox(height: 20),
                            Text(
                              'Devoluciones y novedades',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Las cantidades declaradas no demuestran disponibilidad clínica.',
                            ),
                            if (!c.isLoading &&
                                c.error == null &&
                                c.custodyEvents.isEmpty)
                              const ListTile(
                                title: Text(
                                  'No hay devoluciones ni novedades registradas.',
                                ),
                              ),
                            for (final event in c.custodyEvents)
                              ListTile(
                                title: Text(
                                  '${event['vaccineName']} · ${event['lotNumber']}',
                                ),
                                subtitle: Text(
                                  '${event['vialCount']} frascos · ${_eventStatus(event['status'] as String?)}\n${event['reportNote']}',
                                ),
                                isThreeLine: true,
                                trailing:
                                    widget.admin &&
                                        widget.canWrite &&
                                        event['status'] == 'RETURN_PENDING'
                                    ? TextButton(
                                        onPressed: c.isLoading
                                            ? null
                                            : () => _openCustodyForm(
                                                event,
                                                confirmation: true,
                                              ),
                                        child: const Text('Revisar'),
                                      )
                                    : null,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
  );
}
