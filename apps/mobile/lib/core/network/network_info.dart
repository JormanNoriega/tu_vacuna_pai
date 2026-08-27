import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraccion de conectividad para no acoplar la logica a connectivity_plus.
abstract interface class NetworkInfo {
  /// True si hay alguna conexion de red disponible.
  Future<bool> get isConnected;

  /// Stream que emite la conectividad del dispositivo ante cambios. Se usa
  /// SOLO para ajustar la etiqueta visual del banner offline; NO autoriza ni
  /// desautoriza operaciones (eso lo decide OfflineAuthorizationService).
  Stream<bool> get connectivityChanges;
}

class ConnectivityNetworkInfo implements NetworkInfo {
  ConnectivityNetworkInfo([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Stream<bool> get connectivityChanges =>
      _connectivity.onConnectivityChanged.map(
        (results) =>
            results.any((result) => result != ConnectivityResult.none),
      );
}