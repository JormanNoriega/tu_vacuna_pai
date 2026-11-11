import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

/// Una entrada conserva la misma petición al reintentar una respuesta incierta.
class StockEntryPage extends StatefulWidget {
  const StockEntryPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.vaccineId,
    required this.vaccineName,
    required this.lots,
  });
  final InventoryController controller;
  final String institutionId;
  final String vaccineId;
  final String vaccineName;
  final List<Map<String, dynamic>> lots;

  @override
  State<StockEntryPage> createState() => _StockEntryPageState();
}

class _StockEntryPageState extends State<StockEntryPage> {
  final form = GlobalKey<FormState>();
  final manufacturer = TextEditingController();
  final lotNumber = TextEditingController();
  final doses = TextEditingController();
  final count = TextEditingController();
  final note = TextEditingController();
  final lotId = uuidV4();
  final movementId = uuidV4();
  String? existingId;
  DateTime? expiry;
  Map<String, dynamic>? submitted;
  String? resource;
  bool busy = false;

  @override
  void dispose() {
    manufacturer.dispose();
    lotNumber.dispose();
    doses.dispose();
    count.dispose();
    note.dispose();
    super.dispose();
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'Este dato es obligatorio.' : null;
  String? positive(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n <= 0 || n > 2147483647
        ? 'Ingresa un entero positivo válido.'
        : null;
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (existingId == null && expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de vencimiento.')),
      );
      return;
    }
    resource ??= existingId == null ? 'lots-with-entry' : 'entries';
    submitted ??= {
      'movementId': movementId,
      'vials': int.parse(count.text),
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'note': note.text.trim(),
      if (existingId != null) 'lotId': existingId,
      if (existingId == null) ...{
        'id': lotId,
        'vaccineId': widget.vaccineId,
        'manufacturer': manufacturer.text.trim(),
        'lotNumber': lotNumber.text.trim(),
        'expiresOn': expiry!.toIso8601String().substring(0, 10),
        'dosesPerVial': int.parse(doses.text),
      },
    };
    setState(() => busy = true);
    final ok = await widget.controller.post(
      widget.institutionId,
      resource!,
      submitted!,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final locked = submitted != null || busy;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Agregar existencias')),
        body: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.vaccineName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra únicamente los frascos completos recibidos y contados físicamente.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: existingId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lote'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Registrar lote nuevo'),
                    ),
                    ...widget.lots.map(
                      (l) => DropdownMenuItem(
                        value: l['id'] as String,
                        child: Text(
                          '${l['lotNumber']} · ${l['manufacturer']} · vence ${l['expiresOn']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: locked
                      ? null
                      : (v) => setState(() => existingId = v == '' ? null : v),
                ),
                if (existingId == null) ...[
                  TextFormField(
                    controller: manufacturer,
                    enabled: !locked,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Fabricante'),
                    validator: requiredText,
                  ),
                  TextFormField(
                    controller: lotNumber,
                    enabled: !locked,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Número de lote',
                    ),
                    validator: requiredText,
                  ),
                  TextFormField(
                    controller: doses,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Dosis nominales por frasco',
                    ),
                    validator: positive,
                  ),
                  OutlinedButton.icon(
                    onPressed: locked
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: expiry ?? DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100),
                            );
                            if (date != null && mounted) {
                              setState(() => expiry = date);
                            }
                          },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      expiry == null
                          ? 'Seleccionar vencimiento'
                          : 'Vence: ${expiry!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                ],
                TextFormField(
                  controller: count,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Frascos completos recibidos',
                  ),
                  validator: positive,
                ),
                TextFormField(
                  controller: note,
                  enabled: !locked,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Motivo o soporte',
                  ),
                  validator: requiredText,
                ),
                if (submitted != null && widget.controller.error != null) ...[
                  Text(
                    widget.controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const Text(
                    'Si la respuesta se interrumpió, consulta las existencias antes de iniciar otra operación. El reintento conserva los mismos identificadores.',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Guardando…'
                        : submitted == null
                        ? 'Registrar entrada'
                        : 'Reintentar misma operación',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
