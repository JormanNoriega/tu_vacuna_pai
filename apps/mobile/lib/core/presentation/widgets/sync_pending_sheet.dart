import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../synchronization/sync_operation.dart';
import '../../synchronization/sync_status.dart';
import '../../synchronization/sync_status_controller.dart';
import 'app_snackbar.dart';
import '../offline_messages.dart';

/// Abre la bandeja de comprobantes pendientes por subir.
Future<void> showSyncPendingSheet(
  BuildContext context,
  SyncStatusController controller, {
  bool isOffline = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _SyncPendingSheet(controller: controller, isOffline: isOffline),
  );
}

class _SyncPendingSheet extends StatefulWidget {
  const _SyncPendingSheet({required this.controller, required this.isOffline});

  final SyncStatusController controller;
  final bool isOffline;

  @override
  State<_SyncPendingSheet> createState() => _SyncPendingSheetState();
}

class _SyncPendingSheetState extends State<_SyncPendingSheet> {
  List<OutboxEntry> _entries = const [];
  bool _loading = true;
  bool _syncing = false;

  bool get _hasPending => _entries.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final entries = await widget.controller.pendingEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    if (!_hasPending) {
      AppSnackbar.info(context, 'No hay cambios por sincronizar.');
      return;
    }
    setState(() => _syncing = true);
    final outcome = await widget.controller.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    await _reload();
    if (!mounted) return;
    if (outcome.isSuccess) {
      AppSnackbar.success(context, 'Sincronizacion completada.');
    } else if (widget.isOffline) {
      AppSnackbar.warning(context, OfflineMessages.pendingSync);
    } else {
      AppSnackbar.error(context, 'No se pudo sincronizar: ${outcome.error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Handle(),
            const SizedBox(height: 8),
            _Header(controller: widget.controller),
            const SizedBox(height: 16),
            Flexible(child: _buildBody(context)),
            const SizedBox(height: 16),
            _Footer(
              syncing: _syncing,
              enabled: _hasPending,
              onSync: _sync,
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_entries.isEmpty) return const _EmptyState();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _entries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _ReceiptTile(entry: _entries[index]),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final SyncStatusController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pending = controller.pendingCount;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pendientes por subir',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (pending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$pending',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Se sincronizan solas cuando vuelva la conexion.',
                    style: TextStyle(fontSize: 13, color: AppColors.slate),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Todo sincronizado',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No hay registros pendientes por subir.',
            style: TextStyle(fontSize: 13, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.syncing,
    required this.enabled,
    required this.onSync,
    required this.onClose,
  });

  final bool syncing;
  final bool enabled;
  final VoidCallback onSync;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: enabled && !syncing ? onSync : null,
          icon: syncing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 20),
          label: Text(
            syncing
                ? 'Sincronizando...'
                : (enabled ? 'Sincronizar ahora' : 'Nada por sincronizar'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onClose, child: const Text('Cerrar')),
      ],
    );
  }
}

/// Un comprobante del talonario: sello + etiqueta + estado.
class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final processing = entry.status == SyncOutboxStatus.processing;
    final accent = processing ? AppColors.primary : AppColors.slate;
    final soft = processing ? AppColors.primarySoft : AppColors.surfaceAlt;
    final label = entry.operation.summary ?? _labelFor(entry.operation);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Sello del comprobante.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: soft,
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: .35)),
              ),
              child: Icon(_iconFor(entry.operation), size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(entry),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: entry.status),
          ],
        ),
      ),
    );
  }

  static String _subtitle(OutboxEntry entry) {
    final type = _labelFor(entry.operation);
    final createdAt = entry.createdAt?.toLocal();
    if (createdAt == null) return type;
    final hh = createdAt.hour.toString().padLeft(2, '0');
    final mm = createdAt.minute.toString().padLeft(2, '0');
    return '$type - $hh:$mm';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SyncOutboxStatus status;

  @override
  Widget build(BuildContext context) {
    final processing = status == SyncOutboxStatus.processing;
    final color = processing ? AppColors.primary : AppColors.warning;
    final soft = processing ? AppColors.primarySoft : AppColors.warningSoft;
    final text = processing ? 'Subiendo' : 'Pendiente';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (processing) ...[
            SizedBox.square(
              dimension: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _labelFor(SyncOperation operation) => switch (operation.commandType) {
  SyncCommandType.createPatient => 'Paciente nuevo',
  SyncCommandType.createAttention => 'Atencion',
  SyncCommandType.registerAppliedDose => 'Vacuna aplicada',
  SyncCommandType.completeAttention => 'Cierre de atencion',
};

IconData _iconFor(SyncOperation operation) => switch (operation.commandType) {
  SyncCommandType.createPatient => Icons.person_add_alt_1_rounded,
  SyncCommandType.createAttention => Icons.assignment_rounded,
  SyncCommandType.registerAppliedDose => Icons.vaccines_rounded,
  SyncCommandType.completeAttention => Icons.task_alt_rounded,
};
