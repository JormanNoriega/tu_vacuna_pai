import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'delivery_ui.dart';
import 'receipt_form_page.dart';
import 'difference_resolution_page.dart';
import 'historical_custody_review_page.dart';
import 'delivery_conciliation_page.dart';
import 'custody_event_form_page.dart';
import 'custody_workflow_page.dart';

class DeliveryDetailPage extends StatefulWidget {
  const DeliveryDetailPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignment,
    required this.admin,
    required this.canWrite,
    this.vaccinatorName,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> assignment;
  final bool admin;
  final bool canWrite;
  final String? vaccinatorName;

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  late Map<String, dynamic> _assignment = widget.assignment;
  bool _refreshing = false;
  String? _error;

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    setState(() => _refreshing = true);
    await widget.controller.load(widget.institutionId, admin: widget.admin);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _error = widget.controller.error;
      for (final a in widget.controller.assignments) {
        if (a['id'] == _assignment['id']) _assignment = a;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _assignment;
    final events = widget.controller.custodyEvents.where(
      (e) => e['assignmentId'] == a['id'],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de entrega')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${a['vaccineName']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Lote ${a['lotNumber']} · ${a['vialCount']} frascos'),
            if (widget.vaccinatorName != null)
              Text('Para ${widget.vaccinatorName}'),
            Text(
              a['campaignName'] == null
                  ? 'Entrega directa · Sin jornada'
                  : 'Jornada: ${a['campaignName']}',
            ),
            const SizedBox(height: 16),
            Text(
              deliveryStatus(a['status']),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (a['status'] == 'PARTIALLY_RECEIVED' ||
                a['status'] == 'CLOSED_WITH_DIFFERENCE') ...[
              Text(
                'Recibidos: ${a['receivedVials']} · Resueltos: ${a['resolvedVials'] ?? 0}',
              ),
              if (a['differenceNote'] != null)
                Text('Observación: ${a['differenceNote']}'),
            ],
            if (_refreshing) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refreshing || _error != null
                  ? null
                  : () => _open(
                      CustodyWorkflowPage(
                        controller: widget.controller,
                        institutionId: widget.institutionId,
                        assignment: a,
                        admin: widget.admin,
                        canWrite: widget.canWrite,
                        online: true,
                      ),
                    ),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Continuar a custodia y cierre'),
            ),
            if (widget.admin) ...[
              if (a['status'] == 'IN_TRANSIT' ||
                  a['status'] == 'PARTIALLY_RECEIVED') ...[
                Text(
                  'Siguiente paso: recepción del vacunador',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'El destinatario entra con su cuenta, abre Entregas y jornadas y pulsa Recibir en esta entrega. Debe contar los frascos recibidos e indicar cualquier diferencia. El administrador no confirma en su nombre.',
                ),
                const SizedBox(height: 16),
              ],
              if (a['status'] == 'PARTIALLY_RECEIVED' ||
                  a['status'] == 'CLOSED_WITH_DIFFERENCE')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.rule_outlined),
                  title: const Text('Revisar diferencia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _refreshing || _error != null
                      ? null
                      : () => _open(
                          DifferenceResolutionPage(
                            controller: widget.controller,
                            institutionId: widget.institutionId,
                            assignment: a,
                            canWrite: widget.canWrite,
                          ),
                        ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Ver conciliación'),
                subtitle: const Text(
                  'Cantidades registradas y asuntos pendientes',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _refreshing
                    ? null
                    : () => _open(
                        DeliveryConciliationPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignmentId: a['id'] as String,
                          online: true,
                          canRead: true,
                        ),
                      ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: const Text('Ver historial'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _refreshing
                    ? null
                    : () => _open(
                        HistoricalCustodyReviewPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignmentId: a['id'] as String,
                          online: true,
                          canRead: true,
                        ),
                      ),
              ),
            ] else ...[
              if (a['status'] == 'IN_TRANSIT' ||
                  a['status'] == 'PARTIALLY_RECEIVED')
                FilledButton(
                  onPressed: _refreshing || _error != null
                      ? null
                      : () => _open(
                          ReceiptFormPage(
                            controller: widget.controller,
                            institutionId: widget.institutionId,
                            assignment: a,
                          ),
                        ),
                  child: const Text('Confirmar recepción'),
                ),
              if ((a['receivedVials'] as num? ?? 0) > 0)
                OutlinedButton(
                  onPressed: _refreshing || _error != null
                      ? null
                      : () => _open(
                          CustodyEventFormPage(
                            controller: widget.controller,
                            institutionId: widget.institutionId,
                            record: a,
                            confirmation: false,
                          ),
                        ),
                  child: const Text('Declarar devolución o novedad'),
                ),
            ],
            if (events.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Devoluciones y novedades',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final e in events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${e['vialCount']} frascos · ${custodyEventStatus(e['status'])}',
                  ),
                  subtitle: Text('${e['reportNote'] ?? ''}'),
                  trailing:
                      widget.admin &&
                          widget.canWrite &&
                          e['status'] == 'RETURN_PENDING'
                      ? TextButton(
                          onPressed: _refreshing || _error != null
                              ? null
                              : () => _open(
                                  CustodyEventFormPage(
                                    controller: widget.controller,
                                    institutionId: widget.institutionId,
                                    record: e,
                                    confirmation: true,
                                  ),
                                ),
                          child: const Text('Revisar'),
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String custodyEventStatus(Object? status) => switch (status) {
  'RETURN_PENDING' => 'Devolución pendiente de recepción',
  'RETURN_AVAILABLE' => 'Recibida y reincorporada',
  'RETURN_QUARANTINED' => 'Recibida en cuarentena',
  'INCIDENT_LOST' => 'Pérdida declarada',
  'INCIDENT_QUARANTINED' => 'Inmovilización declarada',
  _ => 'Estado por revisar',
};
