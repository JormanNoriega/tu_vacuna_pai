import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'inventory_controller.dart';
import 'custody_workflow_page.dart';
import 'delivery_ui.dart';
import 'pending_follow_ups_page.dart';

/// Bandeja por entrega: conserva procedencia, no suma entregas como saldo físico.
class CustodyPage extends StatefulWidget {
  const CustodyPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.admin,
    required this.canWrite,
    required this.online,
    this.campaignId,
  });
  final InventoryController controller;
  final String institutionId;
  final String? campaignId;
  final bool admin, canWrite, online;
  @override
  State<CustodyPage> createState() => _CustodyPageState();
}

class _CustodyPageState extends State<CustodyPage> {
  List<Map<String, dynamic>> _assignments = [];
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant CustodyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.institutionId != widget.institutionId ||
        oldWidget.admin != widget.admin ||
        oldWidget.campaignId != widget.campaignId ||
        oldWidget.online != widget.online) {
      _generation++;
      _assignments = [];
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
        _assignments = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await widget.controller.load(widget.institutionId, admin: widget.admin);
    if (!mounted || generation != _generation) return;
    final error = widget.controller.error;
    final assignments = widget.controller.assignments
        .where(
          (a) =>
              widget.campaignId == null || a['campaignId'] == widget.campaignId,
        )
        .map((a) => Map<String, dynamic>.of(a))
        .toList();
    final names = <String, String>{};
    if (widget.admin && error == null) {
      await widget.controller.loadVaccinators(widget.institutionId);
      if (!mounted || generation != _generation) return;
      if (widget.controller.error == null) {
        for (final p in widget.controller.vaccinators) {
          names['${p['id']}'] = '${p['fullName']}';
        }
      }
    }
    setState(() {
      _error = error;
      _assignments = error != null
          ? []
          : assignments
                .map(
                  (a) => {
                    ...a,
                    if (widget.admin)
                      'vaccinatorName':
                          names['${a['vaccinatorId']}'] ??
                          'Vacunador ${a['vaccinatorId']}',
                  },
                )
                .toList();
      _loading = false;
    });
  }

  (String, Color, Color, Color, IconData) _statusStyle(Object? status) => switch (status) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: Text(
        widget.admin ? 'Custodia y cierre' : 'Mi custodia',
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
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text(
              widget.campaignId == null
                  ? 'Seguimiento después de entregar'
                  : 'Custodia de esta jornada',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Abre una entrega para recibir, documentar conteos, vincular aplicaciones y revisar su conciliación. Las jornadas finalizadas también conservan este seguimiento.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.slate,
                height: 1.45,
              ),
            ),
            if (widget.admin && widget.online) ...[
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PendingFollowUpsPage(
                        controller: widget.controller,
                        institutionId: widget.institutionId,
                        online: widget.online,
                        canRead: true,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.pending_actions_rounded,
                          color: Color(0xFF1E60EC),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Devoluciones y correcciones por verificar',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E60EC),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF1E60EC),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!widget.online)
              const DeliveryEmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Sin conexión',
                message: 'Necesitas conexión para consultar la custodia.',
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
                        label: const Text('Reintentar'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_assignments.isEmpty)
                const DeliveryEmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Sin entregas registradas',
                  message:
                      'No hay entregas para este ámbito. No se han creado custodias ni saldos supuestos.',
                ),
              for (final a in _assignments) ...[
                _buildCustodyCard(context, a),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildCustodyCard(BuildContext context, Map<String, dynamic> a) {
    final status = a['status'];
    final (statusLabel, statusBg, statusFg, statusBorder, statusIcon) =
        _statusStyle(status);
    final title =
        '${widget.admin ? '${a['vaccinatorName']} · ' : ''}${a['vaccineName']} · Lote ${a['lotNumber']}';
    final receivedCount = a['receivedVials'] ?? 0;
    final campaignText = a['campaignName'] ?? 'Entrega directa';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustodyWorkflowPage(
                controller: widget.controller,
                institutionId: widget.institutionId,
                assignment: a,
                admin: widget.admin,
                canWrite: widget.canWrite,
                online: widget.online,
              ),
            ),
          );
          if (mounted) await _load();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.vaccines_rounded,
                          size: 14,
                          color: AppColors.slate,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$receivedCount frascos recibidos registrados',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            campaignText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
