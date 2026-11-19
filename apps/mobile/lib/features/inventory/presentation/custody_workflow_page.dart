import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'custody_record_page.dart';
import 'delivery_ui.dart';
import 'receipt_form_page.dart';
import 'custody_event_form_page.dart';
import 'difference_resolution_page.dart';

/// Operate: recepción → conteo y evidencia clínica → revisión. Sin saldo supuesto.
class CustodyWorkflowPage extends StatefulWidget {
  const CustodyWorkflowPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignment,
    required this.admin,
    required this.canWrite,
    required this.online,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> assignment;
  final bool admin, canWrite, online;
  @override
  State<CustodyWorkflowPage> createState() => _CustodyWorkflowPageState();
}

class _CustodyWorkflowPageState extends State<CustodyWorkflowPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant CustodyWorkflowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.institutionId != widget.institutionId ||
        oldWidget.assignment['id'] != widget.assignment['id'] ||
        oldWidget.admin != widget.admin ||
        oldWidget.online != widget.online) {
      _generation++;
      _data = null;
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
        _data = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    await widget.controller.load(widget.institutionId, admin: widget.admin);
    if (!mounted || generation != _generation) return;
    if (widget.controller.error != null) {
      setState(() {
        _loading = false;
        _error = widget.controller.error;
      });
      return;
    }
    final events = widget.controller.custodyEvents
        .where((e) => e['assignmentId'] == widget.assignment['id'])
        .map((e) => Map<String, dynamic>.of(e))
        .toList();
    final data = await widget.controller.loadCustodyWorkflow(
      widget.institutionId,
      '${widget.assignment['id']}',
      admin: widget.admin,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _events = events;
      if (data == null ||
          data['assignmentId'] != widget.assignment['id'] ||
          data['recordingEnabled'] is! bool ||
          data['counts'] is! List ||
          data['clinicalDoses'] is! List ||
          !(data['counts'] as List).every((e) => e is Map<String, dynamic>) ||
          !(data['clinicalDoses'] as List).every(
            (e) => e is Map<String, dynamic>,
          ) ||
          (data['recordingEnabled'] == true &&
              (![
                    'receivedVials',
                    'dispatchedVials',
                    'resolvedVials',
                    'declaredEventVials',
                    'pendingReturnVials',
                    'registeredLinkedDoses',
                    'cancelledLinkedDoses',
                  ].every((k) => data[k] is num) ||
                  data['transferStatus'] is! String ||
                  data['basis'] is! String))) {
        _error = widget.controller.error ?? 'La respuesta de custodia está incompleta. No se mostrarán cifras supuestas.';
      } else {
        _data = data;
      }
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  void _record(
    String action,
    String title,
    String explanation, {
    Map<String, dynamic> fixed = const {},
    bool count = false,
  }) => _open(
    CustodyRecordPage(
      controller: widget.controller,
      institutionId: widget.institutionId,
      resource:
          '${widget.admin ? 'assignments' : 'my-assignments'}/${widget.assignment['id']}/$action',
      title: title,
      explanation: explanation,
      fixed: fixed,
      count: count,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final a = {
      ...widget.assignment,
      if (d != null) ...{
        'status': d['transferStatus'],
        'vialCount': d['dispatchedVials'],
        'receivedVials': d['receivedVials'],
        'resolvedVials': d['resolvedVials'],
      },
    };
    final counts = (d?['counts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final doses =
        (d?['clinicalDoses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final latest = counts.isEmpty ? null : counts.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Custodia y cierre')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${a['vaccineName']} · Lote ${a['lotNumber']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (a['vaccinatorName'] != null)
                Text('Custodio: ${a['vaccinatorName']}'),
              const Text(
                'La transferencia y la custodia se revisan por separado. Un cierre de entrega no devuelve frascos al depósito.',
              ),
              const SizedBox(height: 24),
              if (!widget.online)
                const Text(
                  'Necesitas conexión para consultar o registrar custodia.',
                )
              else if (_loading)
                const LinearProgressIndicator()
              else if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('Reintentar consulta'),
                ),
              ] else if (d?['recordingEnabled'] != true) ...[
                const Text('Registro de custodia pendiente de habilitación'),
                const SizedBox(height: 8),
                const Text(
                  'El servidor debe tener la migración V39 y habilitar el flujo de custodia. Las recepciones y devoluciones existentes siguen disponibles; no se han creado conteos ni cierres ficticios.',
                ),
              ] else ...[
                Text(
                  'Recepción y transferencia',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${d!['receivedVials']} frascos recibidos registrados'),
                if (widget.admin &&
                    {
                      'PARTIALLY_RECEIVED',
                      'CLOSED_WITH_DIFFERENCE',
                    }.contains(a['status']))
                  OutlinedButton(
                    onPressed: () => _open(
                      DifferenceResolutionPage(
                        controller: widget.controller,
                        institutionId: widget.institutionId,
                        assignment: a,
                        canWrite: widget.canWrite,
                      ),
                    ),
                    child: const Text('Revisar diferencias del traslado'),
                  ),
                if (d['finalization'] != null) ...[
                  Text(
                    d['finalization']['kind'] == 'AUTOMATIC'
                        ? 'Transferencia finalizada tras recepción completa'
                        : 'Transferencia finalizada por revisión administrativa',
                  ),
                  Text('${d['finalization']['note']}'),
                  Text('Registrado: ${d['finalization']['recordedAt']}'),
                ] else ...[
                  Text(
                    a['status'] == 'IN_TRANSIT'
                        ? 'Primero confirma los frascos que recibiste físicamente.'
                        : a['status'] == 'PARTIALLY_RECEIVED'
                        ? 'Hay una diferencia de recepción pendiente. Debe resolverse antes de finalizar el traslado.'
                        : 'Recepción registrada. Falta la revisión administrativa para finalizar el traslado.',
                  ),
                  if (widget.admin && widget.canWrite)
                    OutlinedButton(
                      onPressed: () => _record(
                        'transfer-finalizations',
                        'Finalizar transferencia',
                        'Confirma la revisión del traslado. Las diferencias deben estar resueltas; las devoluciones y la custodia siguen abiertas. No es un cierre sanitario ni acredita depósito.',
                      ),
                      child: const Text('Revisar y finalizar transferencia'),
                    ),
                ],
                if (!widget.admin &&
                    {'IN_TRANSIT', 'PARTIALLY_RECEIVED'}.contains(a['status']))
                  FilledButton(
                    onPressed: () => _open(
                      ReceiptFormPage(
                        controller: widget.controller,
                        institutionId: widget.institutionId,
                        assignment: a,
                      ),
                    ),
                    child: const Text('Confirmar recepción'),
                  ),
                if (widget.admin)
                  for (final event in _events.where(
                    (e) => e['status'] == 'RETURN_PENDING',
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Devolución pendiente: ${event['vialCount']} frascos',
                      ),
                      subtitle: Text('${event['reportNote'] ?? ''}'),
                      trailing: !widget.canWrite
                          ? null
                          : TextButton(
                              onPressed: () => _open(
                                CustodyEventFormPage(
                                  controller: widget.controller,
                                  institutionId: widget.institutionId,
                                  record: event,
                                  confirmation: true,
                                ),
                              ),
                              child: const Text('Revisar devolución'),
                            ),
                    ),
                const Divider(height: 40),
                Text(
                  'Conteo de frascos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(custodyStateLabel(d['custodyState'])),
                Text(
                  '${d['declaredEventVials']} frascos con devolución o novedad declarada · ${d['pendingReturnVials']} pendientes de devolución',
                ),
                if (latest == null)
                  const Text('Todavía no hay conteo físico documentado.')
                else ...[
                  Text(
                    'Cerrados: ${latest['closedVials']} · Abiertos: ${latest['openVials']}',
                  ),
                  Text(
                    'Agotados acumulados: ${latest['exhaustedVials']} · Descartados acumulados: ${latest['discardedVials']}',
                  ),
                  Text(
                    'Dosis descartadas declaradas: ${latest['discardedDoses']}',
                  ),
                  Text('Registrado: ${latest['recordedAt']}'),
                  Text('${latest['note']}'),
                  Text(
                    'Diferencia aritmética por explicar: ${d['unaccountedVials']} frascos',
                  ),
                  const Text(
                    'Esta diferencia no es pérdida, saldo disponible ni dictamen sanitario.',
                  ),
                ],
                if (!widget.admin && (d['receivedVials'] as num? ?? 0) > 0) ...[
                  FilledButton(
                    onPressed: () => _record(
                      'custody-counts',
                      'Registrar conteo',
                      'Documenta el conteo actual y los acumulados de esta entrega. No abre frascos, no descuenta existencias y no autoriza conservar ni usar un producto.',
                      count: true,
                    ),
                    child: const Text('Registrar conteo y descartes'),
                  ),
                  OutlinedButton(
                    onPressed: () => _open(
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
                const Divider(height: 40),
                Text(
                  'Aplicaciones clínicas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${d['registeredLinkedDoses']} aplicaciones vigentes vinculadas · ${d['cancelledLinkedDoses']} anuladas por revisar',
                ),
                const Text(
                  'Vincula solo una aplicación realmente registrada, de este vacunador, vacuna y lote. La coincidencia de lote propone opciones, no prueba su origen. Un vínculo no equivale a consumir un frasco.',
                ),
                if (doses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'No hay aplicaciones consultables compatibles. Se requiere permiso clínico; no se crean aplicaciones ni lotes para completar el conteo.',
                    ),
                  ),
                for (final dose in doses)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Aplicación ${inventoryDate(dose['applicationDate'])}',
                    ),
                    subtitle: Text(
                      '${dose['id']}\n${dose['linked'] == true ? 'Vinculada' : 'Sin vínculo'} · ${dose['status'] == 'CANCELLED' || dose['attentionStatus'] == 'CANCELLED' ? 'Anulada: requiere revisión' : 'Vigente'}',
                    ),
                    trailing:
                        dose['linked'] == true ||
                            (widget.admin && !widget.canWrite) ||
                            dose['status'] != 'REGISTERED' ||
                            dose['attentionStatus'] == 'CANCELLED'
                        ? null
                        : TextButton(
                            onPressed: () => _record(
                              'clinical-links',
                              'Vincular aplicación',
                              'Confirma con evidencia que esta aplicación procede de la entrega. No se modifica el registro clínico ni se descuenta inventario.',
                              fixed: {'doseId': dose['id']},
                            ),
                            child: const Text('Vincular'),
                          ),
                  ),
                const Divider(height: 40),
                Text(
                  'Revisión de custodia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'La revisión documenta la evidencia de este corte. No certifica aptitud sanitaria ni el agotamiento de la custodia. Si cambian los datos, se requiere otra revisión.',
                ),
                if (d['review'] != null) ...[
                  Text('Última revisión: ${d['review']['recordedAt']}'),
                  Text('${d['review']['note']}'),
                ],
                if (widget.admin &&
                    widget.canWrite &&
                    latest != null &&
                    d['finalization'] != null &&
                    d['custodyState'] == 'REVIEW_REQUIRED' &&
                    d['unaccountedVials'] == 0 &&
                    d['cancelledLinkedDoses'] == 0)
                  FilledButton(
                    onPressed: () => _record(
                      'custody-reviews',
                      'Revisar conciliación',
                      'Acepta solo la evidencia de este conteo. Los frascos abiertos o cerrados que continúan en custodia y las devoluciones pendientes seguirán visibles.',
                      fixed: {'countId': latest['id'], 'basis': d['basis']},
                    ),
                    child: const Text('Registrar revisión administrativa'),
                  ),
                if (counts.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Historial de conteos'),
                    children: [
                      for (final c in counts)
                        ListTile(
                          title: Text('${c['recordedAt']}'),
                          subtitle: Text(
                            'Cerrados ${c['closedVials']} · Abiertos ${c['openVials']} · Agotados ${c['exhaustedVials']} · Descartados ${c['discardedVials']}\n${c['note']}',
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String custodyStateLabel(Object? value) => switch (value) {
  'COUNT_REQUIRED' => 'Pendiente de conteo',
  'REQUIRES_REVIEW' => 'Diferencias o anulaciones por revisar',
  'REVIEW_REQUIRED' => 'Conteo pendiente de revisión',
  'REVIEWED_CUSTODY_CONTINUES' =>
    'Revisión registrada · Custodia o devoluciones continúan',
  'REVIEWED' => 'Revisión registrada · No certifica cierre sanitario',
  _ => 'Estado por verificar',
};
