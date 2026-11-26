import 'dart:async';

import 'package:flutter/material.dart';

import 'inventory_controller.dart';

/// Consulta online: no confirma devoluciones ni regulariza existencias.
class PendingFollowUpsPage extends StatefulWidget {
  const PendingFollowUpsPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.online,
    required this.canRead,
  });

  final InventoryController controller;
  final String institutionId;
  final bool online;
  final bool canRead;

  @override
  State<PendingFollowUpsPage> createState() => _PendingFollowUpsPageState();
}

class _PendingFollowUpsPageState extends State<PendingFollowUpsPage> {
  StreamSubscription<Map<String, dynamic>>? _changeSub;
  bool _reloadAfterCurrent = false;
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _changeSub = widget.controller.changes.listen((event) {
      if (event['type'] != 'RETURN_DECLARED' || !mounted) return;
      if (_loading) {
        _reloadAfterCurrent = true;
      } else {
        unawaited(_load());
      }
    });
    if (widget.online && widget.canRead) _load();
  }

  @override
  void dispose() {
    unawaited(_changeSub?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PendingFollowUpsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online ||
        oldWidget.canRead != widget.canRead ||
        oldWidget.institutionId != widget.institutionId) {
      _request++;
      if (oldWidget.institutionId != widget.institutionId || !widget.canRead) {
        _items = null;
      }
      _error = null;
      _loading = false;
      if (widget.online && widget.canRead) _load();
    }
  }

  Future<void> _load() async {
    if (!widget.online || !widget.canRead || _loading) return;
    final request = ++_request;
    setState(() {
      _error = null;
      _loading = true;
    });
    final result = await widget.controller.loadPendingFollowUps(
      widget.institutionId,
    );
    if (!mounted || request != _request) return;
    setState(() {
      _loading = false;
      if (result != null) _items = result;
      _error = result == null
          ? widget.controller.error ?? 'No se pudo consultar el seguimiento.'
          : null;
    });
    if (_reloadAfterCurrent) {
      _reloadAfterCurrent = false;
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    final returns = items?.where((e) => e['kind'] == 'RETURN_PENDING').toList();
    final corrections = items
        ?.where((e) => e['kind'] == 'DISPATCH_CORRECTION')
        .toList();
    final unknown = items
        ?.where(
          (e) =>
              e['kind'] != 'RETURN_PENDING' &&
              e['kind'] != 'DISPATCH_CORRECTION',
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento pendiente')),
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
                  Text('Revisión logística', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Estas cantidades no son saldos disponibles ni confirman ubicación o aptitud sanitaria.',
                  ),
                  const SizedBox(height: 20),
                  if (_loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Consultando pendientes…'),
                  ],
                  if (_error != null) ...[
                    Text(_error!),
                    if (items != null && items.isNotEmpty)
                      const Text('Los datos mostrados pueden estar desactualizados.'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ),
                  ],
                  if (items != null && (_error == null || items.isNotEmpty)) ...[
                    if (items.isEmpty)
                      const Text('No hay pendientes en esta consulta.')
                    else ...[
                      _section(context, 'Devoluciones pendientes', returns!),
                      const SizedBox(height: 24),
                      _section(
                        context,
                        'Correcciones sin regularizar',
                        corrections!,
                      ),
                      if (unknown!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _section(context, 'Tipo no reconocido', unknown),
                      ],
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      if (items.isEmpty)
        const Text('Sin registros en esta categoría.')
      else
        for (final item in items) _record(context, item),
    ],
  );

  Widget _record(BuildContext context, Map<String, dynamic> item) {
    final pending = item['pendingVials'];
    final count = pending is int && pending > 0
        ? '$pending frascos'
        : 'Cantidad no disponible';
    final isReturn = item['kind'] == 'RETURN_PENDING';
    final isCorrection = item['kind'] == 'DISPATCH_CORRECTION';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(
          '${item['vaccineName'] ?? 'Vacuna no indicada'} · Lote ${item['lotNumber'] ?? 'no indicado'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          isReturn
              ? '$count pendientes de recepción en depósito'
              : isCorrection
              ? '$count sin regularizar'
              : 'Tipo de seguimiento no reconocido · $count',
        ),
        if (isCorrection)
          const Text(
            'La ubicación y la aptitud deben verificarse; no se presume pérdida.',
          ),
        if (item['note'] is String && (item['note'] as String).isNotEmpty)
          Text('Observación: ${item['note']}'),
        if (item['assignmentId'] != null)
          Text(
            'Entrega: ${item['assignmentId']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}
