import 'package:flutter/material.dart';

import 'inventory_controller.dart';

/// Evidencia original de recepción y novedades; no calcula custodia ni saldo.
class HistoricalCustodyReviewPage extends StatefulWidget {
  const HistoricalCustodyReviewPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignmentId,
    required this.online,
    required this.canRead,
  });

  final InventoryController controller;
  final String institutionId;
  final String assignmentId;
  final bool online;
  final bool canRead;

  @override
  State<HistoricalCustodyReviewPage> createState() =>
      _HistoricalCustodyReviewPageState();
}

class _HistoricalCustodyReviewPageState
    extends State<HistoricalCustodyReviewPage> {
  Map<String, dynamic>? _review;
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.canRead && widget.online) _load();
  }

  @override
  void didUpdateWidget(covariant HistoricalCustodyReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online ||
        oldWidget.canRead != widget.canRead ||
        oldWidget.institutionId != widget.institutionId ||
        oldWidget.assignmentId != widget.assignmentId) {
      _request++;
      _review = null;
      _error = null;
      _loading = false;
      if (widget.canRead && widget.online) _load();
    }
  }

  Future<void> _load() async {
    if (!widget.online || !widget.canRead || _loading) return;
    final request = ++_request;
    setState(() {
      _review = null;
      _error = null;
      _loading = true;
    });
    final data = await widget.controller.loadHistoricalCustodyReview(
      widget.institutionId,
      widget.assignmentId,
    );
    if (!mounted || request != _request) return;
    final valid =
        data != null &&
        data['assignmentId'] == widget.assignmentId &&
        data['receipts'] is List &&
        data['events'] is List &&
        data['reviewReasons'] is List &&
        (data['receipts'] as List).every((e) => e is Map<String, dynamic>) &&
        (data['events'] as List).every((e) => e is Map<String, dynamic>);
    setState(() {
      _loading = false;
      _review = valid ? data : null;
      _error = data == null
          ? widget.controller.error ?? 'No se pudo consultar el historial.'
          : valid
          ? null
          : 'La respuesta del historial está incompleta. Intenta nuevamente.';
    });
  }

  String _status(Object? value) => switch (value) {
    'RETURN_PENDING' => 'Devolución pendiente de recepción',
    'RETURN_AVAILABLE' => 'Devolución recibida y reincorporada',
    'RETURN_QUARANTINED' => 'Devolución recibida en cuarentena',
    'INCIDENT_LOST' => 'Pérdida declarada',
    'INCIDENT_QUARANTINED' => 'Inmovilización declarada',
    _ => 'Estado no reconocido: ${value ?? 'no indicado'}',
  };

  String _reason(Object? value) => switch (value) {
    'DUPLICATE_RECEIPT' => 'Hay referencias de recepción duplicadas.',
    'DUPLICATE_EVENT' => 'Hay referencias de novedades duplicadas.',
    'RECEIPT_SCOPE_MISMATCH' =>
      'Una recepción no coincide con la entrega o lote.',
    'EVENT_SCOPE_MISMATCH' => 'Una novedad no coincide con la entrega o lote.',
    'UNKNOWN_EVENT_STATUS' => 'Hay un estado de novedad no reconocido.',
    'MIXED_RECEIPT_EVIDENCE' => 'Las fuentes de recepción requieren revisión.',
    'INVALID_LEGACY_EVIDENCE' => 'La evidencia histórica no es suficiente.',
    'RECEIPT_TOTAL_MISMATCH' => 'Las cantidades de recepción no coinciden.',
    'EVENTS_EXCEED_RECEIVED' => 'Las novedades superan la cantidad recibida.',
    _ => 'Motivo no reconocido: ${value ?? 'no indicado'}',
  };

  @override
  Widget build(BuildContext context) {
    final data = _review;
    final receipts = (data?['receipts'] as List?) ?? const [];
    final events = (data?['events'] as List?) ?? const [];
    final reasons = (data?['reviewReasons'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de la entrega')),
      body: !widget.canRead
          ? const Center(child: Text('No tienes permiso para esta consulta.'))
          : !widget.online
          ? const Center(child: Text('Esta consulta requiere conexión.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Recepciones y novedades originales. Esta consulta no calcula saldo ni confirma aptitud sanitaria.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Las resoluciones de diferencias y los movimientos se consultan por separado.',
                  ),
                  const SizedBox(height: 20),
                  if (_loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Consultando historial…'),
                  ] else if (_error != null) ...[
                    Text(_error!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ),
                  ] else if (data != null) ...[
                    Text(
                      'Entrega: ${data['assignmentId']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Lote (ID): ${data['lotId'] ?? 'No indicado'}'),
                    Text(
                      'Custodio (ID): ${data['custodianId'] ?? 'No indicado'}',
                    ),
                    if (data['assignmentOnlyReceiptEvidence'] == true) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'La recepción completa consta en la entrega, sin registro individual de recepción. Requiere revisión de la evidencia.',
                      ),
                    ],
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Datos que requieren revisión',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final reason in reasons)
                        Text('• ${_reason(reason)}'),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Recepciones',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (receipts.isEmpty)
                      const Text('No hay registros individuales de recepción.')
                    else
                      for (final item in receipts.cast<Map<String, dynamic>>())
                        _receipt(context, item),
                    const SizedBox(height: 24),
                    Text(
                      'Devoluciones y novedades',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (events.isEmpty)
                      const Text('No hay novedades registradas.')
                    else
                      for (final item in events.cast<Map<String, dynamic>>())
                        _event(context, item),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _receipt(BuildContext context, Map<String, dynamic> item) => _entry(
    context,
    title: 'Recepción: ${item['vials'] ?? 'cantidad no indicada'} frascos',
    lines: [
      'Referencia: ${item['id'] ?? 'No indicada'}',
      'Lote (ID): ${item['lotId'] ?? 'No indicado'}',
      'Recibido por (ID): ${item['receivedBy'] ?? 'No indicado'}',
      'Fecha registrada: ${item['receivedAt'] ?? 'No indicada'}',
      if (item['differenceNote'] is String &&
          (item['differenceNote'] as String).isNotEmpty)
        'Observación: ${item['differenceNote']}',
    ],
  );

  Widget _event(BuildContext context, Map<String, dynamic> item) => _entry(
    context,
    title: _status(item['status']),
    lines: [
      'Referencia: ${item['id'] ?? 'No indicada'}',
      'Lote (ID): ${item['lotId'] ?? 'No indicado'}',
      'Frascos declarados: ${item['vialCount'] ?? 'No indicado'}',
      'Declarado por (ID): ${item['reportedBy'] ?? 'No indicado'}',
      'Fecha registrada: ${item['reportedAt'] ?? 'No indicada'}',
      'Motivo: ${item['reportNote'] ?? 'No indicado'}',
      if (item['confirmedBy'] != null)
        'Confirmado por (ID): ${item['confirmedBy']}',
      if (item['confirmedAt'] != null)
        'Fecha de confirmación: ${item['confirmedAt']}',
      if (item['confirmationNote'] != null)
        'Nota de confirmación: ${item['confirmationNote']}',
    ],
  );

  Widget _entry(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 24),
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      for (final line in lines) Text(line),
    ],
  );
}
