import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';
import 'depot_regularization_page.dart';

class DifferenceResolutionPage extends StatefulWidget {
  const DifferenceResolutionPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignment,
    required this.canWrite,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> assignment;
  final bool canWrite;

  @override
  State<DifferenceResolutionPage> createState() =>
      _DifferenceResolutionPageState();
}

class _DifferenceResolutionPageState extends State<DifferenceResolutionPage> {
  final _form = GlobalKey<FormState>();
  final _count = TextEditingController();
  final _note = TextEditingController();
  final _id = uuidV4();
  String? _kind;
  bool _busy = false;
  bool _loading = true;
  String? _historyError;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _submitted;
  int get _pending =>
      (widget.assignment['vialCount'] as num).toInt() -
      (widget.assignment['receivedVials'] as num).toInt() -
      ((widget.assignment['resolvedVials'] as num?)?.toInt() ?? 0);
  String get _resource =>
      'assignments/${widget.assignment['id']}/difference-resolutions';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    List<Map<String, dynamic>>? data;
    await widget.controller.execute((token) async {
      data = await widget.controller.api.inventoryList(
        token,
        widget.institutionId,
        _resource,
      );
    });
    if (!mounted) return;
    setState(() {
      _history = data ?? [];
      _historyError = data == null
          ? widget.controller.error ?? 'No se pudo consultar el historial.'
          : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    _submitted ??= {
      'id': _id,
      'kind': _kind,
      'vials': int.parse(_count.text),
      'note': _note.text.trim(),
    };
    setState(() => _busy = true);
    final ok = await widget.controller.post(
      widget.institutionId,
      _resource,
      _submitted!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _submitted != null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Revisar diferencia')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.assignment['vaccineName']} · ${widget.assignment['lotNumber']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Diferencia pendiente: $_pending frascos'),
              const SizedBox(height: 8),
              const Text(
                'Una corrección no devuelve frascos al depósito. Su ubicación física debe verificarse y regularizarse por separado.',
              ),
              const SizedBox(height: 16),
              Text(
                'Historial de resoluciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_loading)
                const LinearProgressIndicator()
              else if (_historyError != null)
                TextButton(
                  onPressed: _loadHistory,
                  child: Text('$_historyError Reintentar'),
                )
              else if (_history.isEmpty)
                const Text('No hay resoluciones registradas.')
              else
                for (final event in _history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${event['vialCount']} frascos · ${event['kind'] == 'LOST' ? 'Pérdida confirmada' : 'Corrección de despacho'}',
                    ),
                    subtitle: Text(
                      '${event['note']}\nResponsable: ${event['recordedBy']} · ${event['recordedAt']}${event['kind'] == 'DISPATCH_CORRECTION' ? '\nConfirmados en depósito: ${event['regularizedVials'] ?? 0} de ${event['vialCount']}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: event['kind'] == 'DISPATCH_CORRECTION'
                        ? TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DepotRegularizationPage(
                                    controller: widget.controller,
                                    institutionId: widget.institutionId,
                                    resolution: event,
                                    canWrite: widget.canWrite,
                                  ),
                                ),
                              );
                              if (mounted) await _loadHistory();
                            },
                            child: const Text('Verificar'),
                          )
                        : null,
                  ),
              if (widget.canWrite && _pending > 0) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Resolución documentada',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'LOST',
                      child: Text('Pérdida confirmada'),
                    ),
                    DropdownMenuItem(
                      value: 'DISPATCH_CORRECTION',
                      child: Text('Corrección de despacho'),
                    ),
                  ],
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _kind = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una resolución.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _count,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Frascos a resolver',
                  ),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    return count == null || count < 1 || count > _pending
                        ? 'Ingresa una cantidad entre 1 y $_pending.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  enabled: !locked,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo y evidencia',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe el motivo y la evidencia.'
                      : null,
                ),
                if (_submitted != null) ...[
                  const Text(
                    'Si la respuesta fue incierta, verifica el historial antes de iniciar otra operación. Puedes reintentar esta misma operación.',
                  ),
                  if (widget.controller.error != null)
                    Text(widget.controller.error!),
                ],
                FilledButton(
                  onPressed: locked && _submitted == null
                      ? null
                      : _busy
                      ? null
                      : _submit,
                  child: Text(
                    _submitted == null
                        ? 'Registrar resolución'
                        : 'Reintentar misma operación',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
