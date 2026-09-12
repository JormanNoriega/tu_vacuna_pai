import 'dart:async';

import '../network/network_info.dart';
import 'sync_engine.dart';

/// Dispara el [SyncEngine] por reconexion, por intervalo y bajo demanda.
///
/// No autoriza operaciones: solo decide *cuando* intentar sincronizar. El
/// engine ignora los ciclos solapados.
class SyncScheduler {
  SyncScheduler({
    required this.engine,
    required this.networkInfo,
    this.interval = const Duration(seconds: 60),
  });

  final SyncEngine engine;
  final NetworkInfo networkInfo;
  final Duration interval;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _connectivitySubscription = networkInfo.connectivityChanges.listen(
      (connected) {
        if (connected) unawaited(engine.syncOnce());
      },
    );
    _timer = Timer.periodic(interval, (_) => unawaited(engine.syncOnce()));
    unawaited(engine.syncOnce());
  }

  Future<SyncOutcome> trigger() => engine.syncOnce();

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
