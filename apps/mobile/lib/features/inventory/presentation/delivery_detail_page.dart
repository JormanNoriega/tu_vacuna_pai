import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'inventory_controller.dart';
import 'delivery_ui.dart';
import 'receipt_form_page.dart';
import 'difference_resolution_page.dart';
import 'historical_custody_review_page.dart';
import 'delivery_conciliation_page.dart';
import 'custody_event_form_page.dart';
import 'custody_workflow_page.dart';

class DeliveryDetailPage extends StatefulWidget {
  const DeliveryDetailPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.assignment,
    required this.admin,
    required this.canWrite,
    this.vaccinatorName,
  });
  final InventoryController controller;
  final String institutionId;
  final Map<String, dynamic> assignment;
  final bool admin;
  final bool canWrite;
  final String? vaccinatorName;

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  StreamSubscription<Map<String, dynamic>>? _changeSub;
  bool _reloadAfterCurrent = false;
  late Map<String, dynamic> _assignment = widget.assignment;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _changeSub = widget.controller.changes.listen((event) {
      if (event['assignmentId'] != _assignment['id'] || !mounted) return;
      if (_refreshing) {
        _reloadAfterCurrent = true;
      } else {
        unawaited(_refresh());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changeSub?.cancel());
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _reloadAfterCurrent = true;
      return;
    }
    setState(() => _refreshing = true);
    await widget.controller.load(widget.institutionId, admin: widget.admin);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _error = widget.controller.error;
      for (final a in widget.controller.assignments) {
        if (a['id'] == _assignment['id']) _assignment = a;
      }
    });
    if (_reloadAfterCurrent) {
      _reloadAfterCurrent = false;
      unawaited(_refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _assignment;
    final status = a['status']?.toString();
    final isPending = status == 'IN_TRANSIT' || status == 'PARTIALLY_RECEIVED';
    final isReceived = status == 'RECEIVED';

    final (
      statusLabel,
      statusBg,
      statusFg,
      statusBorder,
      statusIcon,
    ) = switch (status) {
      'RECEIVED' => (
        'Recibida',
        const Color(0xFFECFDF5),
        const Color(0xFF047857),
        const Color(0xFFA7F3D0),
        Icons.check_circle_rounded,
      ),
      'IN_TRANSIT' => (
        'Pendiente de recepción',
        const Color(0xFFFFFBEB),
        const Color(0xFFB45309),
        const Color(0xFFFDE68A),
        Icons.schedule_rounded,
      ),
      'PARTIALLY_RECEIVED' => (
        'Diferencia pendiente',
        const Color(0xFFFFF7ED),
        const Color(0xFFC2410C),
        const Color(0xFFFED7AA),
        Icons.warning_amber_rounded,
      ),
      'CLOSED_WITH_DIFFERENCE' => (
        'Diferencia resuelta',
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
        const Color(0xFFBFDBFE),
        Icons.info_outline_rounded,
      ),
      _ => (
        deliveryStatus(status),
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        const Color(0xFFE2E8F0),
        Icons.help_outline_rounded,
      ),
    };

    final avatarBg = isReceived
        ? const Color(0xFFECFDF5)
        : isPending
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFEFF6FF);

    final avatarFg = isReceived
        ? const Color(0xFF059669)
        : isPending
            ? const Color(0xFFD97706)
            : const Color(0xFF1E60EC);

    final avatarIcon = isReceived
        ? Icons.check_circle_outline_rounded
        : isPending
            ? Icons.inventory_2_outlined
            : Icons.vaccines_outlined;

    final events = widget.controller.custodyEvents
        .where((e) => e['assignmentId'] == a['id'])
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detalle de entrega',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: _refreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFE2E8F0),
                  color: Color(0xFF1E60EC),
                  minHeight: 2,
                ),
              )
            : const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (_error != null) ...[
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
              ),
            ],

            // 1. Resumen de la entrega
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: avatarBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(avatarIcon, color: avatarFg, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a['vaccineName']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (widget.vaccinatorName != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Para ${widget.vaccinatorName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slate,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusFg),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: statusFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetaPill(
                          icon: Icons.tag_rounded,
                          label: 'LOTE',
                          value: 'Lote ${a['lotNumber']}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetaPill(
                          icon: Icons.inventory_2_outlined,
                          label: 'CANTIDAD',
                          value: '${a['vialCount']} frascos',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMetaPill(
                    icon: a['campaignName'] == null
                        ? Icons.local_shipping_outlined
                        : Icons.event_available_rounded,
                    label: 'MODALIDAD',
                    value: a['campaignName'] == null
                        ? 'Entrega directa · Sin jornada'
                        : 'Jornada: ${a['campaignName']}',
                  ),
                  if (a['status'] == 'PARTIALLY_RECEIVED' ||
                      a['status'] == 'CLOSED_WITH_DIFFERENCE') ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Color(0xFFC2410C),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Discrepancia en recepción',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Recibidos: ${a['receivedVials']} · Resueltos: ${a['resolvedVials'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                          if (a['differenceNote'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Observación: ${a['differenceNote']}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF9A3412),
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

            const SizedBox(height: 24),

            // 2. Sección: Acciones disponibles
            const Text(
              'Acciones disponibles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestión de custodia, verificaciones y eventos de lote.',
                style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 14),

            if (widget.admin) ...[
              if (a['status'] == 'IN_TRANSIT' ||
                  a['status'] == 'PARTIALLY_RECEIVED') ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF1E40AF),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Siguiente paso: recepción del vacunador',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'El destinatario entra con su cuenta, abre Recibidos y pulsa Recibir en esta entrega. Debe contar los frascos recibidos e indicar cualquier diferencia. El administrador no confirma en su nombre.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF334155),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildActionCard(
                icon: Icons.fact_check_outlined,
                iconBg: const Color(0xFFEFF6FF),
                iconFg: const Color(0xFF1E60EC),
                title: 'Continuar a custodia y cierre',
                subtitle: 'Supervisión de custodia, balance y cierre administrativo',
                onTap: _refreshing || _error != null
                    ? null
                    : () => _open(
                        CustodyWorkflowPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignment: a,
                          admin: widget.admin,
                          canWrite: widget.canWrite,
                          online: true,
                        ),
                      ),
              ),
              if (a['status'] == 'PARTIALLY_RECEIVED' ||
                  a['status'] == 'CLOSED_WITH_DIFFERENCE')
                _buildActionCard(
                  icon: Icons.rule_outlined,
                  iconBg: const Color(0xFFFFF7ED),
                  iconFg: const Color(0xFFC2410C),
                  title: 'Revisar diferencia',
                  subtitle: 'Resolver discrepancias entre frascos enviados y recibidos',
                  onTap: _refreshing || _error != null
                      ? null
                      : () => _open(
                          DifferenceResolutionPage(
                            controller: widget.controller,
                            institutionId: widget.institutionId,
                            assignment: a,
                            canWrite: widget.canWrite,
                          ),
                        ),
                ),
              _buildActionCard(
                icon: Icons.balance_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconFg: const Color(0xFF2563EB),
                title: 'Ver conciliación',
                subtitle: 'Cantidades registradas y asuntos pendientes',
                onTap: _refreshing
                    ? null
                    : () => _open(
                        DeliveryConciliationPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignmentId: a['id'] as String,
                          online: true,
                          canRead: true,
                        ),
                      ),
              ),
              _buildActionCard(
                icon: Icons.history_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconFg: const Color(0xFF475569),
                title: 'Ver historial',
                subtitle: 'Línea de tiempo de cambios de custodia',
                onTap: _refreshing
                    ? null
                    : () => _open(
                        HistoricalCustodyReviewPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignmentId: a['id'] as String,
                          online: true,
                          canRead: true,
                        ),
                      ),
              ),
            ] else ...[
              if (a['status'] == 'IN_TRANSIT' ||
                  a['status'] == 'PARTIALLY_RECEIVED') ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _refreshing || _error != null
                        ? null
                        : () => _open(
                            ReceiptFormPage(
                              controller: widget.controller,
                              institutionId: widget.institutionId,
                              assignment: a,
                            ),
                          ),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                      ),
                    label: const Text(
                      'Confirmar recepción',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E60EC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildActionCard(
                icon: Icons.fact_check_outlined,
                iconBg: const Color(0xFFEFF6FF),
                iconFg: const Color(0xFF1E60EC),
                title: 'Continuar a custodia y cierre',
                subtitle: 'Arqueo, conteo físico y balance de frascos',
                onTap: _refreshing || _error != null
                    ? null
                    : () => _open(
                        CustodyWorkflowPage(
                          controller: widget.controller,
                          institutionId: widget.institutionId,
                          assignment: a,
                          admin: widget.admin,
                          canWrite: widget.canWrite,
                          online: true,
                        ),
                      ),
              ),
              if ((a['receivedVials'] as num? ?? 0) > 0)
                _buildActionCard(
                  icon: Icons.assignment_return_outlined,
                  iconBg: const Color(0xFFFFF7ED),
                  iconFg: const Color(0xFFEA580C),
                  title: 'Declarar devolución o novedad',
                  subtitle: 'Registra sobrantes, pérdidas o inmovilizaciones',
                  onTap: _refreshing || _error != null
                      ? null
                      : () => _open(
                          CustodyEventFormPage(
                            controller: widget.controller,
                            institutionId: widget.institutionId,
                            record: a,
                            confirmation: false,
                          ),
                        ),
                ),
            ],

            if (events.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Devoluciones y novedades',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${events.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final e in events)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_return_outlined,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e['vialCount']} frascos · ${custodyEventStatus(e['status'])}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                              if ((e['reportNote']?.toString() ?? '')
                                  .isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${e['reportNote']}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.slate,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.admin &&
                          widget.canWrite &&
                          e['status'] == 'RETURN_PENDING')
                        FilledButton.tonal(
                          onPressed: _refreshing || _error != null
                              ? null
                              : () => _open(
                                  CustodyEventFormPage(
                                    controller: widget.controller,
                                    institutionId: widget.institutionId,
                                    record: e,
                                    confirmation: true,
                                  ),
                                ),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text('Revisar'),
                        ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toda acción sobre este lote queda registrada en la cadena de custodia.',
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
  );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconFg, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String custodyEventStatus(Object? status) => switch (status) {
  'RETURN_PENDING' => 'Devolución pendiente de recepción',
  'RETURN_AVAILABLE' => 'Recibida y reincorporada',
  'RETURN_QUARANTINED' => 'Recibida en cuarentena',
  'INCIDENT_LOST' => 'Pérdida declarada',
  'INCIDENT_QUARANTINED' => 'Inmovilización declarada',
  _ => 'Estado por revisar',
};
