import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraccion de conectividad para no acoplar la logica a connectivity_plus.
abstract interface class NetworkInfo {
  /// True si hay alguna conexion de red disponible.
  Future<bool> get isConnected;
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
}