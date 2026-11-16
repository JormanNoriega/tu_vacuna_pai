import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

class DepotRegularizationPage extends StatefulWidget {
  const DepotRegularizationPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.resolution,
    required this.canWrite,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> resolution;
  final bool canWrite;

  @override
  State<DepotRegularizationPage> createState() =>
      _DepotRegularizationPageState();
}

class _DepotRegularizationPageState extends State<DepotRegularizationPage> {
  final _form = GlobalKey<FormState>();
  final _count = TextEditingController();
  final _note = TextEditingController();
  final _id = uuidV4();
  bool _verified = false;
  bool _busy = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _submitted;
  String get _resource =>
      'difference-resolutions/${widget.resolution['id']}/depot-regularizations';
  int get _pending =>
      (widget.resolution['vialCount'] as num).toInt() -
      ((widget.resolution['regularizedVials'] as num?)?.toInt() ?? 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>>? result;
    await widget.controller.execute((token) async {
      result = await widget.controller.api.inventoryList(
        token,
        widget.institutionId,
        _resource,
      );
    });
    if (!mounted) return;
    setState(() {
      _loading = false;
      _history = result ?? [];
      _error = result == null
          ? widget.controller.error ?? 'No se pudo consultar el historial.'
          : null;
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
    if (!_verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirma el conteo y la aptitud antes de continuar.'),
        ),
      );
      return;
    }
    _submitted ??= {
      'id': _id,
      'vials': int.parse(_count.text),
      'note': _note.text.trim(),
      'physicalAndSuitable': true,
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
        appBar: AppBar(title: const Text('Permanencia en depósito')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Frascos pendientes de verificar: $_pending',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta operación acredita el saldo del depósito por una corrección de despacho; no registra una devolución. No acredita frascos vencidos.',
              ),
              const SizedBox(height: 16),
              Text(
                'Historial de regularizaciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_loading)
                const LinearProgressIndicator()
              else if (_error != null)
                TextButton(onPressed: _load, child: Text('$_error Reintentar'))
              else if (_history.isEmpty)
                const Text('No hay regularizaciones registradas.')
              else
                for (final event in _history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${event['vialCount']} frascos'),
                    subtitle: Text(
                      '${event['note']}\nResponsable: ${event['recordedBy']} · ${event['recordedAt']}',
                    ),
                    isThreeLine: true,
                  ),
              if (widget.canWrite && _pending > 0) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _count,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Frascos contados',
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
                    labelText: 'Evidencia del conteo y revisión',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe el conteo y la revisión.'
                      : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _verified,
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _verified = value ?? false),
                  title: const Text(
                    'Confirmo la presencia física y que son aptos según el protocolo.',
                  ),
                ),
                if (_submitted != null) ...[
                  const Text(
                    'Ante una respuesta incierta, consulta el historial antes de iniciar otra operación. Puedes reintentar esta misma operación.',
                  ),
                  if (widget.controller.error != null)
                    Text(widget.controller.error!),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _submitted == null
                        ? 'Confirmar permanencia'
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
