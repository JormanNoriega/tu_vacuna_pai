import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'inventory_controller.dart';
import 'custody_record_page.dart';
import 'delivery_ui.dart';
import 'receipt_form_page.dart';
import 'custody_event_form_page.dart';
import 'difference_resolution_page.dart';

/// Operate: recepción → conteo y evidencia clínica → revisión. Sin saldo supuesto.
class CustodyWorkflowPage extends StatefulWidget {
  const CustodyWorkflowPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignment,
    required this.admin,
    required this.canWrite,
    required this.online,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> assignment;
  final bool admin, canWrite, online;
  @override
  State<CustodyWorkflowPage> createState() => _CustodyWorkflowPageState();
}

class _CustodyWorkflowPageState extends State<CustodyWorkflowPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant CustodyWorkflowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.institutionId != widget.institutionId ||
        oldWidget.assignment['id'] != widget.assignment['id'] ||
        oldWidget.admin != widget.admin ||
        oldWidget.online != widget.online) {
      _generation++;
      _data = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!widget.online) {
      setState(() {
        _loading = false;
        _data = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    await widget.controller.load(widget.institutionId, admin: widget.admin);
    if (!mounted || generation != _generation) return;
    if (widget.controller.error != null) {
      setState(() {
        _loading = false;
        _error = widget.controller.error;
      });
      return;
    }
    final events = widget.controller.custodyEvents
        .where((e) => e['assignmentId'] == widget.assignment['id'])
        .map((e) => Map<String, dynamic>.of(e))
        .toList();
    final data = await widget.controller.loadCustodyWorkflow(
      widget.institutionId,
      '${widget.assignment['id']}',
      admin: widget.admin,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _events = events;
      if (data == null ||
          data['assignmentId'] != widget.assignment['id'] ||
          data['recordingEnabled'] is! bool ||
          data['counts'] is! List ||
          data['clinicalDoses'] is! List ||
          !(data['counts'] as List).every((e) => e is Map<String, dynamic>) ||
          !(data['clinicalDoses'] as List).every(
            (e) => e is Map<String, dynamic>,
          ) ||
          (data['recordingEnabled'] == true &&
              (![
                    'receivedVials',
                    'dispatchedVials',
                    'resolvedVials',
                    'declaredEventVials',
                    'pendingReturnVials',
                    'registeredLinkedDoses',
                    'cancelledLinkedDoses',
                  ].every((k) => data[k] is num) ||
                  data['transferStatus'] is! String ||
                  data['basis'] is! String))) {
        _error = widget.controller.error ??
            'La respuesta de custodia está incompleta. No se mostrarán cifras supuestas.';
      } else {
        _data = data;
      }
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  void _record(
    String action,
    String title,
    String explanation, {
    Map<String, dynamic> fixed = const {},
    bool count = false,
  }) => _open(
    CustodyRecordPage(
      controller: widget.controller,
      institutionId: widget.institutionId,
      resource:
          '${widget.admin ? 'assignments' : 'my-assignments'}/${widget.assignment['id']}/$action',
      title: title,
      explanation: explanation,
      fixed: fixed,
      count: count,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final a = {
      ...widget.assignment,
      if (d != null) ...{
        'status': d['transferStatus'],
        'vialCount': d['dispatchedVials'],
        'receivedVials': d['receivedVials'],
        'resolvedVials': d['resolvedVials'],
      },
    };
    final counts = (d?['counts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final doses =
        (d?['clinicalDoses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final latest = counts.isEmpty ? null : counts.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Custodia y cierre',
          style: TextStyle(
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // 1. Tarjeta Hero de cabecera
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.fact_check_outlined,
                            color: Color(0xFF1E60EC),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a['vaccineName']} · Lote ${a['lotNumber']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (a['vaccinatorName'] != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Custodio: ${a['vaccinatorName']}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    const Text(
                      'La transferencia y la custodia se revisan por separado. Un cierre de entrega no devuelve frascos al depósito.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.slate,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (!widget.online)
                const DeliveryEmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Sin conexión',
                  message:
                      'Necesitas conexión para consultar o registrar custodia.',
                )
              else if (_loading)
                const LinearProgressIndicator(
                  backgroundColor: Color(0xFFE2E8F0),
                  color: Color(0xFF1E60EC),
                )
              else if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reintentar consulta'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (d?['recordingEnabled'] != true) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Registro de custodia pendiente de habilitación',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El servidor debe tener la migración V39 y habilitar el flujo de custodia. Las recepciones y devoluciones existentes siguen disponibles; no se han creado conteos ni cierres ficticios.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.slate,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // 2. Sección: Recepción y transferencia
                _buildCardSection(
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Recepción y transferencia',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.vaccines_rounded,
                              size: 15,
                              color: Color(0xFF1E60EC),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${d!['receivedVials']} frascos recibidos registrados',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E60EC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.admin &&
                          {
                            'PARTIALLY_RECEIVED',
                            'CLOSED_WITH_DIFFERENCE',
                          }.contains(a['status'])) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _open(
                            DifferenceResolutionPage(
                              controller: widget.controller,
                              institutionId: widget.institutionId,
                              assignment: a,
                              canWrite: widget.canWrite,
                            ),
                          ),
                          icon: const Icon(Icons.rule_outlined, size: 18),
                          label: const Text('Revisar diferencias del traslado'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC2410C),
                            side: const BorderSide(color: Color(0xFFFED7AA)),
                            backgroundColor: const Color(0xFFFFF7ED),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (d['finalization'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF047857),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      d['finalization']['kind'] == 'AUTOMATIC'
                                          ? 'Transferencia finalizada tras recepción completa'
                                          : 'Transferencia finalizada por revisión administrativa',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d['finalization']['note']}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Registrado: ${d['finalization']['recordedAt']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            a['status'] == 'IN_TRANSIT'
                                ? 'Primero confirma los frascos que recibiste físicamente.'
                                : a['status'] == 'PARTIALLY_RECEIVED'
                                ? 'Hay una diferencia de recepción pendiente. Debe resolverse antes de finalizar el traslado.'
                                : 'Recepción registrada. Falta la revisión administrativa para finalizar el traslado.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (widget.admin && widget.canWrite) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _record(
                              'transfer-finalizations',
                              'Finalizar transferencia',
                              'Confirma la revisión del traslado. Las diferencias deben estar resueltas; las devoluciones y la custodia siguen abiertas. No es un cierre sanitario ni acredita depósito.',
                            ),
                            icon: const Icon(Icons.verified_rounded, size: 18),
                            label: const Text('Revisar y finalizar transferencia'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E60EC),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              backgroundColor: const Color(0xFFEFF6FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (!widget.admin &&
                          {'IN_TRANSIT', 'PARTIALLY_RECEIVED'}.contains(a['status'])) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _open(
                              ReceiptFormPage(
                                controller: widget.controller,
                                institutionId: widget.institutionId,
                                assignment: a,
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Confirmar recepción'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E60EC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (widget.admin)
                        for (final event in _events.where(
                          (e) => e['status'] == 'RETURN_PENDING',
                        )) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Devolución pendiente: ${event['vialCount']} frascos',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF9A3412),
                                        ),
                                      ),
                                      if (event['reportNote'] != null)
                                        Text(
                                          '${event['reportNote']}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFFC2410C),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (widget.canWrite)
                                  FilledButton.tonal(
                                    onPressed: () => _open(
                                      CustodyEventFormPage(
                                        controller: widget.controller,
                                        institutionId: widget.institutionId,
                                        record: event,
                                        confirmation: true,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFFC2410C),
                                    ),
                                    child: const Text('Revisar devolución'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Sección: Conteo de frascos
                _buildCardSection(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFFD97706),
                  title: 'Conteo de frascos',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      custodyStateLabel(d['custodyState']),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['declaredEventVials']} frascos con devolución o novedad declarada · ${d['pendingReturnVials']} pendientes de devolución',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (latest == null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Todavía no hay conteo físico documentado.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.slate,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cerrados: ${latest['closedVials']} · Abiertos: ${latest['openVials']}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Agotados acumulados: ${latest['exhaustedVials']} · Descartados acumulados: ${latest['discardedVials']}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dosis descartadas declaradas: ${latest['discardedDoses']}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Registrado: ${latest['recordedAt']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (latest['note'] != null &&
                                  '${latest['note']}'.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${latest['note']}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                              if (d['unaccountedVials'] != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFED7AA)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Diferencia aritmética por explicar: ${d['unaccountedVials']} frascos',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF9A3412),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Esta diferencia no es pérdida, saldo disponible ni dictamen sanitario.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFFC2410C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (!widget.admin && (d['receivedVials'] as num? ?? 0) > 0) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () => _record(
                              'custody-counts',
                              'Registrar conteo',
                              'Documenta el conteo actual y los acumulados de esta entrega. No abre frascos, no descuenta existencias y no autoriza conservar ni usar un producto.',
                              count: true,
                            ),
                            icon: const Icon(Icons.add_task_rounded, size: 18),
                            label: const Text('Registrar conteo y descartes'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E60EC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () => _open(
                              CustodyEventFormPage(
                                controller: widget.controller,
                                institutionId: widget.institutionId,
                                record: a,
                                confirmation: false,
                              ),
                            ),
                            icon: const Icon(Icons.assignment_return_outlined, size: 18),
                            label: const Text('Declarar devolución o novedad'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Sección: Aplicaciones clínicas
                _buildCardSection(
                  icon: Icons.vaccines_outlined,
                  iconColor: const Color(0xFF059669),
                  title: 'Aplicaciones clínicas',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['registeredLinkedDoses']} aplicaciones vigentes vinculadas · ${d['cancelledLinkedDoses']} anuladas por revisar',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Vincula solo una aplicación realmente registrada, de este vacunador, vacuna y lote. La coincidencia de lote propone opciones, no prueba su origen. Un vínculo no equivale a consumir un frasco.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                      if (doses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No hay aplicaciones consultables compatibles. Se requiere permiso clínico; no se crean aplicaciones ni lotes para completar el conteo.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.slate,
                            ),
                          ),
                        ),
                      for (final dose in doses) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Aplicación ${inventoryDate(dose['applicationDate'])}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dose['id']}\n${dose['linked'] == true ? 'Vinculada' : 'Sin vínculo'} · ${dose['status'] == 'CANCELLED' || dose['attentionStatus'] == 'CANCELLED' ? 'Anulada: requiere revisión' : 'Vigente'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (dose['linked'] != true &&
                                  !(widget.admin && !widget.canWrite) &&
                                  dose['status'] == 'REGISTERED' &&
                                  dose['attentionStatus'] != 'CANCELLED')
                                FilledButton.tonal(
                                  onPressed: () => _record(
                                    'clinical-links',
                                    'Vincular aplicación',
                                    'Confirma con evidencia que esta aplicación procede de la entrega. No se modifica el registro clínico ni se descuenta inventario.',
                                    fixed: {'doseId': dose['id']},
                                  ),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    foregroundColor: const Color(0xFF1E60EC),
                                  ),
                                  child: const Text('Vincular'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5. Sección: Revisión de custodia
                _buildCardSection(
                  icon: Icons.verified_outlined,
                  iconColor: const Color(0xFF475569),
                  title: 'Revisión de custodia',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'La revisión documenta la evidencia de este corte. No certifica aptitud sanitaria ni el agotamiento de la custodia. Si cambian los datos, se requiere otra revisión.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                      if (d['review'] != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Última revisión: ${d['review']['recordedAt']}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d['review']['note']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.admin &&
                          widget.canWrite &&
                          latest != null &&
                          d['finalization'] != null &&
                          d['custodyState'] == 'REVIEW_REQUIRED' &&
                          d['unaccountedVials'] == 0 &&
                          d['cancelledLinkedDoses'] == 0) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () => _record(
                              'custody-reviews',
                              'Revisar conciliación',
                              'Acepta solo la evidencia de este conteo. Los frascos abiertos o cerrados que continúan en custodia y las devoluciones pendientes seguirán visibles.',
                              fixed: {'countId': latest['id'], 'basis': d['basis']},
                            ),
                            icon: const Icon(Icons.fact_check_rounded, size: 18),
                            label: const Text('Registrar revisión administrativa'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E60EC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (counts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                              'Historial de conteos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            children: [
                              for (final c in counts)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${c['recordedAt']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cerrados ${c['closedVials']} · Abiertos ${c['openVials']} · Agotados ${c['exhaustedVials']} · Descartados ${c['discardedVials']}\n${c['note']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

String custodyStateLabel(Object? value) => switch (value) {
  'COUNT_REQUIRED' => 'Pendiente de conteo',
  'REQUIRES_REVIEW' => 'Diferencias o anulaciones por revisar',
  'REVIEW_REQUIRED' => 'Conteo pendiente de revisión',
  'REVIEWED_CUSTODY_CONTINUES' =>
    'Revisión registrada · Custodia o devoluciones continúan',
  'REVIEWED' => 'Revisión registrada · No certifica cierre sanitario',
  _ => 'Estado por verificar',
};
