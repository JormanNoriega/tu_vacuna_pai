import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

/// Declaracion online o confirmacion de recepcion fisica; no calcula consumo.
class CustodyEventFormPage extends StatefulWidget {
  const CustodyEventFormPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.record,
    required this.confirmation,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> record;
  final bool confirmation;

  @override
  State<CustodyEventFormPage> createState() => _CustodyEventFormPageState();
}

class _CustodyEventFormPageState extends State<CustodyEventFormPage> {
  final _form = GlobalKey<FormState>();
  final _count = TextEditingController();
  final _note = TextEditingController();
  final _eventId = uuidV4();
  String? _choice;
  bool _verified = false;
  bool _busy = false;
  Map<String, dynamic>? _submitted;

  @override
  void dispose() {
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.confirmation && !_verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirma primero la recepción física y el destino seleccionado.',
          ),
        ),
      );
      return;
    }
    _submitted ??= widget.confirmation
        ? {'disposition': _choice, 'note': _note.text.trim()}
        : {
            'id': _eventId,
            'assignmentId': widget.record['id'],
            'vials': int.parse(_count.text),
            'kind': _choice,
            'note': _note.text.trim(),
          };
    setState(() => _busy = true);
    final resource = widget.confirmation
        ? 'custody-events/${widget.record['id']}/confirm'
        : 'custody-events';
    final ok = await widget.controller.post(
      widget.institutionId,
      resource,
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
        appBar: AppBar(
          title: Text(
            widget.confirmation
                ? 'Confirmar devolución'
                : 'Devolución o novedad',
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.record['vaccineName']} · Lote ${widget.record['lotNumber']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.confirmation
                    ? '${widget.record['vialCount']} frascos declarados. Verifica que la cantidad recibida coincida antes de confirmar.'
                    : 'Declara solo frascos cerrados contados físicamente. Las dosis aplicadas no descuentan todavía estos registros.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _choice,
                decoration: InputDecoration(
                  labelText: widget.confirmation
                      ? 'Destino tras revisión'
                      : 'Tipo de registro',
                ),
                isExpanded: true,
                items: widget.confirmation
                    ? const [
                        DropdownMenuItem(
                          value: 'QUARANTINE',
                          child: Text('Cuarentena · no disponible'),
                        ),
                        DropdownMenuItem(
                          value: 'AVAILABLE',
                          child: Text('Reincorporar al depósito'),
                        ),
                      ]
                    : const [
                        DropdownMenuItem(
                          value: 'RETURN',
                          child: Text('Devolución pendiente'),
                        ),
                        DropdownMenuItem(
                          value: 'LOST',
                          child: Text('Pérdida o extravío'),
                        ),
                        DropdownMenuItem(
                          value: 'QUARANTINE',
                          child: Text('Inmovilización / cuarentena'),
                        ),
                      ],
                onChanged: locked
                    ? null
                    : (value) => setState(() {
                        _choice = value;
                        _verified = false;
                      }),
                validator: (value) =>
                    value == null ? 'Selecciona una opción.' : null,
              ),
              if (!widget.confirmation)
                TextFormField(
                  controller: _count,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Frascos cerrados',
                  ),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    if (n == null || n <= 0 || n > 2147483647) {
                      return 'Ingresa un entero positivo válido.';
                    }
                    if (n > (widget.record['vialCount'] as int)) {
                      return 'Supera los frascos de la entrega.';
                    }
                    return null;
                  },
                ),
              TextFormField(
                controller: _note,
                enabled: !locked,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.confirmation
                      ? 'Resultado de la revisión'
                      : 'Motivo o detalle',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Describe lo ocurrido.'
                    : null,
              ),
              if (widget.confirmation) ...[
                Text(
                  _choice == null
                      ? 'Selecciona el destino después de revisar físicamente los frascos.'
                      : _choice == 'AVAILABLE'
                      ? 'Reincorporar aumentará el saldo. Solo procede tras revisar el estado y las condiciones de conservación según el procedimiento autorizado.'
                      : 'La cuarentena no aumenta las existencias disponibles. La liberación requiere un procedimiento posterior.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _verified,
                  onChanged: locked
                      ? null
                      : (value) => setState(() => _verified = value ?? false),
                  title: const Text(
                    'Confirmo la recepción física y el destino seleccionado',
                  ),
                ),
              ] else
                const Text(
                  'La devolución no suma existencias hasta que la institución confirme su recepción y destino.',
                ),
              if (widget.controller.error != null && _submitted != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const Text(
                  'Si se interrumpió la respuesta, verifica el listado antes de iniciar otra operación. El reintento conserva los mismos datos.',
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Enviando…'
                      : _submitted != null
                      ? 'Reintentar misma operación'
                      : widget.confirmation
                      ? 'Confirmar recepción'
                      : 'Registrar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
