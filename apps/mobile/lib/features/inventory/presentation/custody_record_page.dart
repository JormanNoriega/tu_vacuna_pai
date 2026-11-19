import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

/// Una evidencia = una operación con UUID estable. Nunca genera movimientos.
class CustodyRecordPage extends StatefulWidget {
  const CustodyRecordPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.resource,
    required this.title,
    required this.explanation,
    this.fixed = const {},
    this.count = false,
  });
  final InventoryController controller;
  final String institutionId, resource, title, explanation;
  final Map<String, dynamic> fixed;
  final bool count;
  @override
  State<CustodyRecordPage> createState() => _CustodyRecordPageState();
}

class _CustodyRecordPageState extends State<CustodyRecordPage> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _fields = {
    'closedVials': ('Frascos cerrados que conservas', TextEditingController()),
    'openVials': ('Frascos abiertos que conservas', TextEditingController()),
    'exhaustedVials': ('Frascos agotados acumulados', TextEditingController()),
    'discardedVials': (
      'Frascos descartados acumulados',
      TextEditingController(),
    ),
    'discardedDoses': ('Dosis descartadas acumuladas', TextEditingController()),
  };
  Map<String, dynamic>? _request;
  bool _busy = false, _exit = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    for (final f in _fields.values) {
      f.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revisa antes de registrar otra vez'),
        content: const Text(
          'La operación podría haberse guardado si se interrumpió la respuesta. Al salir se pierde este reintento. Consulta el historial antes de crear otra evidencia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar aquí'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir y consultar'),
          ),
        ],
      ),
    );
    if (mounted && yes == true) {
      setState(() => _exit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, false);
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    _request ??= {
      'id': uuidV4(),
      ...widget.fixed,
      'note': _note.text.trim(),
      if (widget.count)
        for (final f in _fields.entries) f.key: int.parse(f.value.$2.text),
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.controller.post(
      widget.institutionId,
      widget.resource,
      _request!,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok
          ? null
          : widget.controller.error ?? 'No se pudo confirmar el registro.';
    });
    if (ok) {
      setState(() => _exit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && (_request == null || _exit),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(widget.explanation),
              if (widget.count) ...[
                const SizedBox(height: 12),
                const Text(
                  'Cuenta únicamente los frascos de esta entrega. No incluyas los ya declarados como devolución, pérdida o cuarentena. Los acumulados sustituyen el conteo anterior: no se suman entre sí. Usa cero solo cuando lo hayas comprobado.',
                ),
                for (final f in _fields.values) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: f.$2,
                    enabled: _request == null,
                    decoration: InputDecoration(labelText: f.$1),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 2147483647
                          ? 'Indica una cantidad entera, incluido cero si corresponde.'
                          : null;
                    },
                  ),
                ],
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _note,
                enabled: _request == null,
                decoration: const InputDecoration(
                  labelText: 'Evidencia y observaciones',
                ),
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Describe cómo verificaste este registro.'
                    : null,
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const Text(
                  'El reintento conserva los mismos datos e identificador.',
                ),
                if ({
                  400,
                  401,
                  403,
                  404,
                  422,
                  503,
                }.contains(widget.controller.lastPostStatus))
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _request = null;
                            _error = null;
                          }),
                    child: const Text('Corregir registro rechazado'),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Guardando…'
                      : _request == null
                      ? 'Guardar evidencia'
                      : 'Reintentar mismo registro',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
