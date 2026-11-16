import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

class ReceiptFormPage extends StatefulWidget {
  const ReceiptFormPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignment,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> assignment;

  @override
  State<ReceiptFormPage> createState() => _ReceiptFormPageState();
}

class _ReceiptFormPageState extends State<ReceiptFormPage> {
  final _form = GlobalKey<FormState>();
  final _count = TextEditingController();
  final _note = TextEditingController();
  final _id = uuidV4();
  Map<String, dynamic>? _submitted;
  bool _busy = false;

  int get _total => (widget.assignment['vialCount'] as num).toInt();
  int get _received =>
      (widget.assignment['receivedVials'] as num?)?.toInt() ?? 0;
  int get _pending =>
      _total -
      _received -
      ((widget.assignment['resolvedVials'] as num?)?.toInt() ?? 0);
  bool get _initial => widget.assignment['status'] == 'IN_TRANSIT';

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
      'vials': int.parse(_count.text),
      'note': _note.text.trim(),
    };
    setState(() => _busy = true);
    final ok = await widget.controller.post(
      widget.institutionId,
      'assignments/${widget.assignment['id']}/receipts',
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
        appBar: AppBar(title: const Text('Registrar recepción')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.assignment['vaccineName']} · Lote ${widget.assignment['lotNumber']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enviados: $_total · Recibidos: $_received · Pendientes: $_pending frascos',
              ),
              const SizedBox(height: 12),
              const Text(
                'Cuenta los frascos recibidos físicamente. Una diferencia no se considera pérdida automáticamente.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _count,
                enabled: !locked,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Frascos recibidos ahora',
                ),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  if (count == null ||
                      count < 0 ||
                      count > _pending ||
                      (!_initial && count == 0)) {
                    return 'Ingresa una cantidad válida hasta $_pending.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                enabled: !locked,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observación de la diferencia',
                ),
                validator: (value) {
                  final count = int.tryParse(_count.text);
                  if (_initial &&
                      count != null &&
                      count < _pending &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Describe la diferencia.';
                  }
                  return null;
                },
              ),
              if (_submitted != null) ...[
                const Text(
                  'Si la respuesta fue incierta, verifica el listado antes de iniciar otra operación. Puedes reintentar esta misma operación.',
                ),
                if (widget.controller.error != null)
                  Text(widget.controller.error!),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _submitted == null
                      ? 'Confirmar recepción'
                      : 'Reintentar misma operación',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
