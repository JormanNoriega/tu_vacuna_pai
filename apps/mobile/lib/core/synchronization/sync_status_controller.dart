import 'package:flutter/foundation.dart';

import 'sync_engine.dart';
import 'sync_outbox.dart';

/// Proyeccion observable del estado de sincronizacion para la UI.
///
/// No es un estado del contrato: agrega el outbox (`pendingCount`) y el ultimo
/// resultado del [SyncEngine] para pintar banners/insignias.
class SyncStatusController extends ChangeNotifier {
  SyncStatusController({required this.outbox, required this.engine});

  final SyncOutboxRepository outbox;
  final SyncEngine engine;

  int _pendingCount = 0;
  bool _syncing = false;
  SyncOutcome? _lastOutcome;

  int get pendingCount => _pendingCount;
  bool get syncing => _syncing;
  SyncOutcome? get lastOutcome => _lastOutcome;
  bool get hasPending => _pendingCount > 0;

  Future<void> refresh() async {
    _pendingCount = await outbox.pendingCount();
    notifyListeners();
  }

  Future<SyncOutcome> syncNow() async {
    _syncing = true;
    notifyListeners();
    try {
      _lastOutcome = await engine.syncOnce();
      return _lastOutcome!;
    } finally {
      _syncing = false;
      await refresh();
    }
  }
}
