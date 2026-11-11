import 'dart:async';

import 'package:flutter/foundation.dart';

import 'sync_engine.dart';
import 'sync_operation.dart';
import 'sync_outbox.dart';

/// Proyeccion observable del estado de sincronizacion para la UI.
///
/// No es un estado del contrato: cuenta cambios sin confirmar (incluidos fallos
/// y cuarentenas) y observa ciclos manuales y automaticos del [SyncEngine].
class SyncStatusController extends ChangeNotifier {
  SyncStatusController({required this.outbox, required this.engine}) {
    _syncing = engine.isRunning;
    engine.addListener(_onEngineChanged);
    _subscription = outbox.watchUnresolvedEntries().listen(_updateEntries);
  }

  final SyncOutboxRepository outbox;
  final SyncEngine engine;

  int _pendingCount = 0;
  bool _syncing = false;
  SyncOutcome? _lastOutcome;
  List<OutboxEntry> _entries = const [];
  StreamSubscription<List<OutboxEntry>>? _subscription;
  Future<void>? _completion;
  bool _disposed = false;

  int get pendingCount => _pendingCount;
  bool get syncing => _syncing;
  SyncOutcome? get lastOutcome => _lastOutcome;
  bool get hasPending => _pendingCount > 0;
  List<OutboxEntry> get entries => _entries;

  Future<void> refresh() async {
    _updateEntries(await outbox.unresolvedEntries());
  }

  void _updateEntries(List<OutboxEntry> entries) {
    if (_disposed) return;
    _entries = List.unmodifiable(entries);
    _pendingCount = entries.length;
    notifyListeners();
  }

  void _onEngineChanged() {
    if (_disposed) return;
    if (engine.isRunning) {
      _syncing = true;
      _lastOutcome = null;
      notifyListeners();
    } else {
      _completion = _finishCycle();
    }
  }

  Future<void> _finishCycle() async {
    await refresh();
    if (_disposed) return;
    _lastOutcome = engine.lastOutcome;
    _syncing = engine.isRunning;
    notifyListeners();
  }

  /// Comprobantes aun por subir (para la bandeja de pendientes).
  Future<List<OutboxEntry>> pendingEntries() => outbox.unresolvedEntries();

  Future<SyncOutcome> syncNow() async {
    if (_syncing || engine.isRunning) return const SyncOutcome(skipped: true);
    final outcome = await engine.syncOnce();
    await _completion;
    return outcome;
  }

  @override
  void dispose() {
    _disposed = true;
    engine.removeListener(_onEngineChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
