import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';
import 'delivery_ui.dart';

// THESIS: preparar una entrega empieza por la persona, no por el depósito.
// OWN-WORLD: Material, superficies claras, azul solo para acción y selección.
// STORY: elegir vacunador, añadir lotes y frascos, confirmar una entrega física.
// FIRST VIEWPORT: destinatario arriba, vacunas debajo, confirmación al final.
// FORM: formulario progresivo fijado por el usuario; jornada solo por contexto.
class DeliveryFormPage extends StatefulWidget {
  const DeliveryFormPage({
    super.key,
    required this.controller,
    required this.institutionId,
    this.vaccinator,
    this.campaign,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic>? vaccinator;
  final Map<String, dynamic>? campaign;

  @override
  State<DeliveryFormPage> createState() => _DeliveryFormPageState();
}

class _DeliveryLine {
  final key = uuidV4();
  String? lotId;
  final count = TextEditingController();
  Map<String, dynamic>? request;
  bool saved = false;
  void dispose() => count.dispose();
}

class _DeliveryFormPageState extends State<DeliveryFormPage> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _lines = <_DeliveryLine>[_DeliveryLine()];
  List<Map<String, dynamic>> _lots = [];
  List<Map<String, dynamic>> _people = [];
  String? _personId;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _locked = false;
  bool _allowExit = false;
  bool _definitiveFailure = false;

  String get _personName {
    if (widget.vaccinator != null) {
      return '${widget.vaccinator!['name'] ?? widget.vaccinator!['fullName']}';
    }
    for (final p in _people) {
      if (p['id'] == _personId) return '${p['fullName']}';
    }
    return 'Vacunador';
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hay entregas por confirmar'),
        content: const Text(
          'Las entregas ya registradas no se desharán. Si una respuesta se interrumpió, revisa las entregas antes de crear otra: podría haberse guardado.\n\nAl salir se perderá este formulario y sus reintentos pendientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir revisando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir y revisar entregas'),
          ),
        ],
      ),
    );
    if (mounted && exit == true) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _correctRejected() {
    setState(() {
      _locked = false;
      _definitiveFailure = false;
      _error = null;
      for (final line in _lines.where((l) => !l.saved)) {
        line.request = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _personId = widget.vaccinator?['id'] as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final c = widget.controller;
    await c.loadLots(widget.institutionId);
    if (!mounted) return;
    if (c.error != null) {
      setState(() {
        _error = c.error;
        _loading = false;
      });
      return;
    }
    final lots = List<Map<String, dynamic>>.of(c.lots);
    if (widget.vaccinator == null) {
      await c.loadVaccinators(widget.institutionId);
      if (!mounted) return;
    }
    // El servidor vuelve a validar saldo, institución, vencimiento y permisos.
    // Colombia no aplica cambios estacionales: UTC-5.
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _lots = lots.where((lot) {
        final expiry = DateTime.tryParse('${lot['expiresOn']}');
        return (lot['availableVials'] as num? ?? 0) > 0 &&
            expiry != null &&
            !expiry.isBefore(today);
      }).toList();
      _people = List.of(c.vaccinators);
      _error = c.error;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _lot(String? id) {
    for (final lot in _lots) {
      if (lot['id'] == id) return lot;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_locked) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar entrega'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para $_personName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final line in _lines.where((l) => !l.saved))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_lot(line.lotId)?['vaccineName']} · Lote ${_lot(line.lotId)?['lotNumber']}\n${line.count.text} frascos',
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Registra solo lo que vas a entregar físicamente. Los frascos saldrán del depósito y el vacunador deberá confirmar su recepción.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar entrega'),
            ),
          ],
        ),
      );
      if (!mounted || confirm != true) return;
      final time = DateTime.now().toUtc().toIso8601String();
      for (final line in _lines.where((l) => !l.saved)) {
        line.request = {
          'movementId': uuidV4(),
          'assignmentId': uuidV4(),
          'lotId': line.lotId,
          'vaccinatorId': _personId,
          'vials': int.parse(line.count.text),
          'occurredAt': time,
          'note': _note.text.trim(),
          if (widget.campaign != null) 'campaignId': widget.campaign!['id'],
        };
      }
      _locked = true;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    for (final line in _lines.where((l) => !l.saved)) {
      final ok = await widget.controller.post(
        widget.institutionId,
        'assignments',
        line.request!,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _definitiveFailure = {
            400,
            401,
            403,
            404,
            422,
          }.contains(widget.controller.lastPostStatus);
          _error =
              widget.controller.error ?? 'No se pudo confirmar la entrega.';
        });
        return;
      }
      setState(() => line.saved = true);
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _allowExit = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _lines.where((l) => l.saved).length;
    return PopScope(
      canPop: !_busy && (!_locked || _allowExit),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.campaign == null ? 'Entrega directa' : 'Asignar vacunas',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          if (_error != null && !_locked) ...[
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Reintentar carga'),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (widget.campaign != null) ...[
                            Text(
                              '${widget.campaign!['name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${widget.campaign!['location']} · ${campaignDates(widget.campaign!)}',
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            '¿Quién recibe?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (widget.vaccinator != null)
                            Text(
                              '${widget.vaccinator!['name'] ?? widget.vaccinator!['fullName']}',
                            )
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _personId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Vacunador',
                              ),
                              items: _people
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p['id'] as String,
                                      child: Text(
                                        '${p['fullName']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _locked || saved > 0
                                  ? null
                                  : (v) => setState(() => _personId = v),
                              validator: (v) => v == null
                                  ? 'Elige al vacunador que recibirá los frascos.'
                                  : null,
                            ),
                          if (widget.vaccinator == null && _people.isEmpty)
                            const Text(
                              'No hay vacunadores activos disponibles.',
                            ),
                          const SizedBox(height: 32),
                          Text(
                            '¿Qué vacunas le entregas?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Selecciona cada lote y la cantidad de frascos completos. Verifica su conservación antes de entregarlo.',
                          ),
                          if (_lots.isEmpty)
                            const DeliveryEmptyState(
                              title: 'No hay lotes disponibles para entregar',
                              message: 'Registra existencias desde Inventario. Los lotes sin saldo o vencidos no se pueden seleccionar aquí.',
                            )
                          else ...[
                            for (final line in _lines) _lineFields(line),
                            if (!_locked)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _lines.length >= _lots.length
                                      ? null
                                      : () => setState(
                                          () => _lines.add(_DeliveryLine()),
                                        ),
                                  icon: const Icon(Icons.add),
                                  label: const Text(
                                    'Añadir otra vacuna o lote',
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _note,
                            enabled: !_locked,
                            maxLength: 1000,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Motivo de la entrega',
                              hintText: 'Ej.: vacunación rutinaria del turno de mañana',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Indica el motivo o soporte de la entrega.'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          if (_error != null && _locked) ...[
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$saved de ${_lines.length} lotes confirmados. Reintenta solo los pendientes con los mismos identificadores. Si sales, revisa las entregas antes de registrar otra.',
                            ),
                            if (_definitiveFailure)
                              TextButton(
                                onPressed: _correctRejected,
                                child: const Text(
                                  'Corregir pendientes rechazados',
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                          FilledButton(
                            onPressed:
                                _busy ||
                                    _lots.isEmpty ||
                                    (_error != null && !_locked)
                                ? null
                                : _submit,
                            child: Text(
                              _busy
                                  ? 'Registrando $saved de ${_lines.length}…'
                                  : _locked
                                  ? 'Reintentar pendientes'
                                  : 'Revisar entrega',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Cada lote se registra por separado. La recepción la confirma el vacunador.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _lineFields(_DeliveryLine line) {
    final lot = _lot(line.lotId);
    final locked = _locked || line.saved;
    return Padding(
      key: ValueKey(line.key),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Vacuna ${_lines.indexOf(line) + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (line.saved) const Chip(label: Text('Entrega registrada')),
              if (!locked && _lines.length > 1)
                IconButton(
                  tooltip: 'Quitar vacuna',
                  onPressed: () => setState(() {
                    _lines.remove(line);
                    line.dispose();
                  }),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: line.lotId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vacuna y lote'),
            items: _lots
                .where(
                  (lot) =>
                      lot['id'] == line.lotId ||
                      !_lines.any((other) => other.lotId == lot['id']),
                )
                .map(
                  (lot) => DropdownMenuItem(
                    value: lot['id'] as String,
                    child: Text(
                      '${lot['vaccineName']} · ${lot['lotNumber']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: locked ? null : (v) => setState(() => line.lotId = v),
            validator: (v) =>
                v == null ? 'Selecciona una vacuna y su lote.' : null,
          ),
          if (lot != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${lot['availableVials']} frascos en depósito · Vence ${inventoryDate(lot['expiresOn'])}',
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: line.count,
            enabled: !locked,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Frascos completos'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1 || n > 2147483647) {
                return 'Ingresa una cantidad entera mayor que cero.';
              }
              if (!locked && n > (lot?['availableVials'] as num? ?? 0)) {
                return 'Supera los frascos disponibles de este lote.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
        ],
      ),
    );
  }
}
