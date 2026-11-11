import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'inventory_form_page.dart';
import 'campaign_form_page.dart';
import 'custody_event_form_page.dart';
import 'inventory_report.dart';

/// Inventario fisico online; el catalogo clinico sigue siendo independiente.
class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.admin,
    required this.online,
    required this.canWrite,
  });
  final InventoryController controller;
  final String institutionId;
  final bool admin;
  final bool online;
  final bool canWrite;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  @override
  void initState() {
    super.initState();
    if (widget.online) _load();
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

  Future<void> _receive(Map<String, dynamic> assignment) async {
    final count = assignment['vialCount'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar recepción'),
        content: Text(
          'Confirma únicamente si recibiste los $count frascos completos del lote ${assignment['lotNumber']}. Si hay diferencias, consulta con tu administrador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.controller.post(
      widget.institutionId,
      'assignments/${assignment['id']}/receive',
      {'vials': count},
    );
    if (ok) await _load();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.admin ? 'Asignaciones y jornadas' : 'Mis entregas'),
      actions: [
        if (widget.admin && widget.online)
          IconButton(
            tooltip: 'Generar informe CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: widget.controller.isLoading
                ? null
                : () async {
                    try {
                      final ok = await shareInventoryReport(
                        widget.controller,
                        widget.institutionId,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.controller.error ??
                                  'No se pudo generar el informe.',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo compartir el informe.'),
                          ),
                        );
                      }
                    }
                  },
          ),
      ],
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
              return RefreshIndicator(
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
                    if (widget.admin) ...[
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
                                          institutionId: widget.institutionId,
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
                              widget.canWrite && campaign['status'] == 'ACTIVE'
                              ? TextButton(
                                  onPressed: c.isLoading
                                      ? null
                                      : () => _finishCampaign(campaign),
                                  child: const Text('Finalizar'),
                                )
                              : null,
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Frascos disponibles para asignar',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Selecciona las acciones del lote para entregar frascos a un vacunador.',
                      ),
                      if (!c.isLoading && c.error == null && c.lots.isEmpty)
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
                              ? PopupMenuButton<String>(
                                  tooltip: 'Acciones del lote',
                                  enabled: !c.isLoading,
                                  onSelected: (value) {
                                    if (value == 'dispatch') {
                                      _openForm(isLot: false, lot: lot);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'dispatch',
                                      child: Text('Entregar frascos'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                    ],
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
                        title: Text('${a['vaccineName']} · ${a['lotNumber']}'),
                        subtitle: Text(
                          '${a['vialCount']} frascos · ${a['status'] == 'RECEIVED' ? 'Recibida' : 'En tránsito'}${a['campaignName'] != null ? '\nJornada: ${a['campaignName']}' : ''}',
                        ),
                        trailing: !widget.admin && a['status'] == 'IN_TRANSIT'
                            ? TextButton(
                                onPressed: c.isLoading
                                    ? null
                                    : () => _receive(a),
                                child: const Text('Recibir'),
                              )
                            : !widget.admin && a['status'] == 'RECEIVED'
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
                ),
              );
            },
          ),
  );
}
