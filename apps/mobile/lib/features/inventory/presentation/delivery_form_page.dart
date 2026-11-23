import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
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

  InputDecoration _fieldDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(color: AppColors.slate, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E60EC), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
    );
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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            widget.campaign == null ? 'Entrega directa' : 'Asignar vacunas',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        children: [
                          if (_error != null && !_locked) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.campaign != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.event_available_rounded,
                                      color: Color(0xFF1E60EC),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${widget.campaign!['name']}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${widget.campaign!['location']} · ${campaignDates(widget.campaign!)}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.slate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. Destinatario
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFF1E60EC),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '¿Quién recibe?',
                                            style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Profesional de salud a cargo de la custodia',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.slate,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (widget.vaccinator != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF059669)),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${widget.vaccinator!['name'] ?? widget.vaccinator!['fullName']}',
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    initialValue: _personId,
                                    isExpanded: true,
                                    decoration: _fieldDecoration(
                                      labelText: 'Vacunador',
                                      prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.slate),
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
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'No hay vacunadores activos disponibles.',
                                      style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. Encabezado de Vacunas
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.vaccines_outlined,
                                  color: Color(0xFF1E60EC),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '¿Qué vacunas le entregas?',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Selecciona cada lote y la cantidad de frascos completos. Verifica su conservación antes de entregarlo.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.slate,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          if (_lots.isEmpty)
                            const DeliveryEmptyState(
                              title: 'No hay lotes disponibles para entregar',
                              message:
                                  'Registra existencias desde Inventario. Los lotes sin saldo o vencidos no se pueden seleccionar aquí.',
                            )
                          else ...[
                            for (final line in _lines) _lineFields(line),
                            if (!_locked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: _lines.length >= _lots.length
                                        ? null
                                        : () => setState(
                                            () => _lines.add(_DeliveryLine()),
                                          ),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text(
                                      'Añadir otra vacuna o lote',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E60EC),
                                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],

                          // 3. Motivo de la entrega
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.edit_note_rounded,
                                        color: Color(0xFF1E60EC),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Motivo de la entrega',
                                            style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Justificación o soporte administrativo del suministro',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.slate,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _note,
                                  enabled: !_locked,
                                  maxLength: 1000,
                                  minLines: 2,
                                  maxLines: 3,
                                  decoration: _fieldDecoration(
                                    labelText: 'Motivo de la entrega',
                                    hintText: 'Ej.: vacunación rutinaria del turno de mañana',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Indica el motivo o soporte de la entrega.'
                                      : null,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          if (_error != null && _locked) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Error al registrar entregas',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$saved de ${_lines.length} lotes confirmados. Reintenta solo los pendientes con los mismos identificadores. Si sales, revisa las entregas antes de registrar otra.',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                                  ),
                                  if (_definitiveFailure) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _correctRejected,
                                      child: const Text('Corregir pendientes rechazados'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed:
                                  _busy ||
                                      _lots.isEmpty ||
                                      (_error != null && !_locked)
                                  ? null
                                  : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E60EC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _busy
                                    ? 'Registrando $saved de ${_lines.length}…'
                                    : _locked
                                    ? 'Reintentar pendientes'
                                    : 'Revisar entrega',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cada lote se registra por separado. La recepción la confirma el vacunador.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    final index = _lines.indexOf(line);

    return Container(
      key: ValueKey(line.key),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Text(
                  'Vacuna ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E60EC),
                  ),
                ),
              ),
              if (line.saved) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text(
                    'Entrega registrada',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!locked && _lines.length > 1)
                IconButton(
                  tooltip: 'Quitar vacuna',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _lines.remove(line);
                    line.dispose();
                  }),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: line.lotId,
            isExpanded: true,
            decoration: _fieldDecoration(
              labelText: 'Vacuna y lote',
              prefixIcon: const Icon(Icons.vaccines_rounded, size: 20, color: AppColors.slate),
            ),
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
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF1E60EC)),
                  const SizedBox(width: 6),
                  Text(
                    '${lot['availableVials']} frascos en depósito · Vence ${inventoryDate(lot['expiresOn'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: line.count,
            enabled: !locked,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration(
              labelText: 'Frascos completos',
              prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 20, color: AppColors.slate),
            ),
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
        ],
      ),
    );
  }
}
