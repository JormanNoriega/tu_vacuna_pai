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
    this.onAfterSync,
  });

  final SyncEngine engine;
  final NetworkInfo networkInfo;
  final Duration interval;

  /// Callback opcional tras cada ciclo (exito o error). Sirve para refrescar la
  /// proyeccion de estado en la UI ([SyncStatusController.refresh]).
  final Future<void> Function()? onAfterSync;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _timer;
  bool _started = false;

  Future<void> _run() async {
    await engine.syncOnce();
    await onAfterSync?.call();
  }

  void start() {
    if (_started) return;
    _started = true;
    _connectivitySubscription = networkInfo.connectivityChanges.listen((
      connected,
    ) {
      if (connected) unawaited(_run());
    });
    _timer = Timer.periodic(interval, (_) => unawaited(_run()));
    unawaited(_run());
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
