import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

/// Una sola intención conserva sus identificadores y datos ante un reintento.
class InventoryFormPage extends StatefulWidget {
  const InventoryFormPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.isLot,
    this.lot,
  });
  final InventoryController controller;
  final String institutionId;
  final bool isLot;
  final Map<String, dynamic>? lot;

  @override
  State<InventoryFormPage> createState() => _InventoryFormPageState();
}

class _InventoryFormPageState extends State<InventoryFormPage> {
  final _form = GlobalKey<FormState>();
  final _manufacturer = TextEditingController();
  final _lotNumber = TextEditingController();
  final _doses = TextEditingController();
  final _count = TextEditingController();
  final _note = TextEditingController();
  final _id = uuidV4();
  final _movementId = uuidV4();
  String? _selectedId;
  String? _campaignId;
  DateTime? _expiry;
  Map<String, dynamic>? _submitted;
  bool _busy = false;
  bool _optionsReady = false;
  List<Map<String, dynamic>> _choices = const [];
  List<Map<String, dynamic>> _campaigns = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOptions();
    });
  }

  Future<void> _loadOptions() async {
    await widget.controller.loadFormOptions(
      widget.institutionId,
      isLot: widget.isLot,
    );
    if (mounted) {
      setState(() {
        _choices = List.of(
          widget.isLot
              ? widget.controller.vaccines
              : widget.controller.vaccinators,
        );
        _campaigns = List.of(widget.controller.campaigns);
        _optionsReady = true;
      });
    }
  }

  @override
  void dispose() {
    _manufacturer.dispose();
    _lotNumber.dispose();
    _doses.dispose();
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este dato es obligatorio.'
      : null;
  String? _positive(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed != null && parsed > 0 && parsed <= 2147483647
        ? null
        : 'Ingresa un entero positivo válido.';
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.isLot && _expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de vencimiento.')),
      );
      return;
    }
    _submitted ??= widget.isLot
        ? {
            'id': _id,
            'vaccineId': _selectedId,
            'manufacturer': _manufacturer.text.trim(),
            'lotNumber': _lotNumber.text.trim(),
            'expiresOn': _expiry!.toIso8601String().substring(0, 10),
            'dosesPerVial': int.parse(_doses.text),
          }
        : {
            'movementId': _movementId,
            'assignmentId': _id,
            'lotId': widget.lot!['id'],
            'vaccinatorId': _selectedId,
            'vials': int.parse(_count.text),
            'occurredAt': DateTime.now().toUtc().toIso8601String(),
            'note': _note.text.trim(),
            if (_campaignId != null) 'campaignId': _campaignId,
          };
    setState(() => _busy = true);
    final ok = await widget.controller.post(
      widget.institutionId,
      widget.isLot ? 'lots' : 'assignments',
      _submitted!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final choices = _choices;
    final locked = _submitted != null || _busy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isLot ? 'Nuevo lote' : 'Entregar frascos'),
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!_optionsReady ||
                (controller.isLoading && _submitted == null)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error != null && _submitted == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(controller.error!),
                      TextButton(
                        onPressed: _loadOptions,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!widget.isLot) ...[
                    Text(
                      '${widget.lot!['vaccineName']} · Lote ${widget.lot!['lotNumber']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${widget.lot!['availableVials']} frascos en depósito. La entrega queda en tránsito hasta su confirmación.',
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _campaignId,
                      decoration: const InputDecoration(
                        labelText: 'Jornada (opcional)',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Sin jornada'),
                        ),
                        ..._campaigns.map(
                          (campaign) => DropdownMenuItem<String>(
                            value: campaign['id'] as String,
                            child: Text(
                              '${campaign['name']} · ${campaign['startsOn']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: locked
                          ? null
                          : (value) => setState(
                              () => _campaignId = value == '' ? null : value,
                            ),
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _selectedId,
                    decoration: InputDecoration(
                      labelText: widget.isLot ? 'Vacuna' : 'Vacunador',
                    ),
                    isExpanded: true,
                    items: choices
                        .map(
                          (v) => DropdownMenuItem<String>(
                            value:
                                (widget.isLot ? v['vaccineId'] : v['id'])
                                    as String,
                            child: Text(
                              (widget.isLot ? v['name'] : v['fullName'])
                                  as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (value) => setState(() => _selectedId = value),
                    validator: (v) =>
                        v == null ? 'Selecciona una opción.' : null,
                  ),
                  if (choices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.isLot
                            ? 'No hay vacunas habilitadas.'
                            : 'No hay vacunadores activos disponibles.',
                      ),
                    ),
                  if (widget.isLot) ...[
                    TextFormField(
                      controller: _manufacturer,
                      enabled: !locked,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Fabricante',
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _lotNumber,
                      enabled: !locked,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Número de lote',
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _doses,
                      enabled: !locked,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Dosis nominales por frasco',
                        helperText:
                            'Capacidad nominal, no disponibilidad sanitaria.',
                      ),
                      validator: _positive,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: locked
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _expiry ?? DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100),
                              );
                              if (date != null && mounted) {
                                setState(() => _expiry = date);
                              }
                            },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _expiry == null
                            ? 'Seleccionar vencimiento'
                            : 'Vencimiento: ${_expiry!.toIso8601String().substring(0, 10)}',
                      ),
                    ),
                    const Text(
                      'Crear el lote no registra existencias. Después registra una entrada o conteo físico.',
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _count,
                      enabled: !locked,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Frascos completos',
                      ),
                      validator: (value) {
                        final invalid = _positive(value);
                        if (invalid != null) return invalid;
                        return int.parse(value!) >
                                (widget.lot!['availableVials'] as int)
                            ? 'Supera el saldo mostrado. Actualiza si es necesario.'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: _note,
                      enabled: !locked,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Motivo o soporte',
                      ),
                      validator: _required,
                    ),
                    const Text(
                      'La jornada es opcional. Esta entrega no autoriza consumo offline.',
                    ),
                  ],
                  if (controller.error != null && _submitted != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const Text(
                      'Si se interrumpió la respuesta, verifica el listado antes de iniciar otra operación. Reintentar conserva los mismos datos e identificadores.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy || choices.isEmpty ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Enviando…'
                          : _submitted != null
                          ? 'Reintentar misma operación'
                          : widget.isLot
                          ? 'Crear lote'
                          : 'Registrar entrega',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
