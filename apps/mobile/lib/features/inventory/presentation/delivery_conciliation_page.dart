import 'package:flutter/material.dart';

import 'inventory_controller.dart';

/// Estado registrado para conciliación; no calcula saldo ni acredita depósito.
class DeliveryConciliationPage extends StatefulWidget {
  const DeliveryConciliationPage({
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
  State<DeliveryConciliationPage> createState() =>
      _DeliveryConciliationPageState();
}

class _DeliveryConciliationPageState extends State<DeliveryConciliationPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.canRead && widget.online) _load();
  }

  @override
  void didUpdateWidget(covariant DeliveryConciliationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online ||
        oldWidget.canRead != widget.canRead ||
        oldWidget.institutionId != widget.institutionId ||
        oldWidget.assignmentId != widget.assignmentId) {
      _request++;
      _data = null;
      _error = null;
      _loading = false;
      if (widget.canRead && widget.online) _load();
    }
  }

  Future<void> _load() async {
    if (!widget.online || !widget.canRead || _loading) return;
    final request = ++_request;
    setState(() {
      _data = null;
      _error = null;
      _loading = true;
    });
    final data = await widget.controller.loadConciliation(
      widget.institutionId,
      widget.assignmentId,
    );
    if (!mounted || request != _request) return;
    final valid =
        data != null &&
        data['assignmentId'] == widget.assignmentId &&
        data['resolutions'] is List &&
        data['pendingReturns'] is List &&
        data['reviewReasons'] is List &&
        (data['resolutions'] as List).every((e) => e is Map<String, dynamic>) &&
        (data['pendingReturns'] as List).every(
          (e) => e is Map<String, dynamic>,
        );
    setState(() {
      _loading = false;
      _data = valid ? data : null;
      _error = data == null
          ? widget.controller.error ?? 'No se pudo consultar la conciliación.'
          : valid
          ? null
          : 'La respuesta de conciliación está incompleta. Intenta nuevamente.';
    });
  }

  int _count(Object? value) => value is num ? value.toInt() : 0;

  String _status(Object? value) => switch (value) {
    'IN_TRANSIT' => 'En tránsito',
    'PARTIALLY_RECEIVED' => 'Diferencia pendiente',
    'RECEIVED' => 'Recibida',
    'CLOSED_WITH_DIFFERENCE' => 'Diferencia resuelta',
    _ => 'Estado no reconocido: ${value ?? 'no indicado'}',
  };

  String _kind(Object? value) => switch (value) {
    'LOST' => 'Pérdida confirmada',
    'DISPATCH_CORRECTION' => 'Corrección de despacho',
    _ => 'Tipo no reconocido: ${value ?? 'no indicado'}',
  };

  String _reason(Object? value) => switch (value) {
    'NEGATIVE_PENDING_DIFFERENCE' =>
      'Las cantidades registradas superan lo despachado.',
    'RECEIPT_TOTAL_MISMATCH' =>
      'La suma de recepciones no coincide con lo recibido registrado.',
    'RESOLUTION_TOTAL_MISMATCH' =>
      'La suma de resoluciones no coincide con lo resuelto registrado.',
    'UNKNOWN_RESOLUTION_KIND' => 'Hay un tipo de resolución no reconocido.',
    'REGULARIZATION_EXCEEDS_RESOLUTION' =>
      'Una regularización supera los frascos de su resolución.',
    'STATUS_PENDING_MISMATCH' =>
      'El estado de la entrega no coincide con la diferencia pendiente.',
    _ => 'Motivo no reconocido: ${value ?? 'no indicado'}',
  };

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final resolutions = (data?['resolutions'] as List?) ?? const [];
    final returns = (data?['pendingReturns'] as List?) ?? const [];
    final reasons = (data?['reviewReasons'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Conciliación de la entrega')),
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
                    'Cantidades y referencias registradas. Esta consulta no calcula existencia física, no confirma ubicación ni acredita aptitud sanitaria.',
                  ),
                  const SizedBox(height: 20),
                  if (_loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Consultando conciliación…'),
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
                      '${data['vaccineName'] ?? 'Vacuna no indicada'} · ${data['lotNumber'] ?? 'Lote no indicado'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Estado: ${_status(data['status'])}'),
                    if (data['status'] == 'CLOSED_WITH_DIFFERENCE')
                      const Text(
                        'La diferencia resuelta no implica cierre administrativo de la entrega.',
                      ),
                    const SizedBox(height: 16),
                    _summary(context, data),
                    if (data['assignmentOnlyReceiptEvidence'] == true) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'La recepción completa consta en la entrega, sin registro individual de recepción. Requiere revisión de la evidencia.',
                      ),
                    ],
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Datos que requieren revisión',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final reason in reasons)
                        Text('• ${_reason(reason)}'),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Resoluciones de diferencia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (resolutions.isEmpty)
                      const Text('No hay resoluciones registradas.')
                    else
                      for (final item
                          in resolutions.cast<Map<String, dynamic>>())
                        _resolution(context, item),
                    const SizedBox(height: 24),
                    Text(
                      'Devoluciones pendientes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (returns.isEmpty)
                      const Text('No hay devoluciones pendientes de recepción.')
                    else
                      for (final item in returns.cast<Map<String, dynamic>>())
                        _pendingReturn(context, item),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summary(BuildContext context, Map<String, dynamic> data) {
    final dispatched = _count(data['dispatchedVials']);
    final received = _count(data['receivedVials']);
    final resolved = _count(data['resolvedVials']);
    final pending = _count(data['pendingDifferenceVials']);
    final lost = _count(data['lostVials']);
    final corrected = _count(data['dispatchCorrectedVials']);
    final regularized = _count(data['regularizedVials']);
    final toVerify = _count(data['pendingVerificationVials']);
    final returns = _count(data['pendingReturnVials']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Despachados: $dispatched frascos'),
        Text('Recibidos: $received frascos'),
        Text('Resueltos: $resolved frascos'),
        Text('Diferencia pendiente: $pending frascos'),
        const Divider(height: 24),
        Text('Pérdidas confirmadas: $lost frascos'),
        Text('Correcciones de despacho: $corrected frascos'),
        Text('Regularizadas en depósito: $regularized frascos'),
        Text('Correcciones por verificar: $toVerify frascos'),
        const Divider(height: 24),
        Text('Devoluciones pendientes: $returns frascos'),
      ],
    );
  }

  Widget _resolution(BuildContext context, Map<String, dynamic> item) => _entry(
    context,
    title: '${_kind(item['kind'])}: ${_count(item['vialCount'])} frascos',
    lines: [
      'Referencia: ${item['id'] ?? 'No indicada'}',
      'Regularizados: ${_count(item['regularizedVials'])} frascos',
      'Por verificar: ${_count(item['pendingVials'])} frascos',
      'Motivo: ${item['note'] ?? 'No indicado'}',
      'Registrado por (ID): ${item['recordedBy'] ?? 'No indicado'}',
      'Fecha registrada: ${item['recordedAt'] ?? 'No indicada'}',
    ],
  );

  Widget _pendingReturn(BuildContext context, Map<String, dynamic> item) =>
      _entry(
        context,
        title: 'Devolución: ${_count(item['vialCount'])} frascos',
        lines: [
          'Referencia: ${item['id'] ?? 'No indicada'}',
          'Declarada por (ID): ${item['reportedBy'] ?? 'No indicado'}',
          'Fecha registrada: ${item['reportedAt'] ?? 'No indicada'}',
          'Motivo: ${item['note'] ?? 'No indicado'}',
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
