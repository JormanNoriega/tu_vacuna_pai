import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Servicio de geolocalizacion no bloqueante para capturar la ubicacion del
/// punto de atencion donde se realiza la vacunacion.
class LocationService {
  const LocationService();

  /// Intenta obtener la posicion actual (latitud y longitud).
  ///
  /// Politica no bloqueante y tolerante a fallos:
  /// - Solicita permiso al usuario si aun no se ha determinado (primera vez).
  /// - Si el GPS esta apagado, el permiso fue denegado o la lectura excede
  ///   [timeLimit] (por defecto 4s), intenta `getLastKnownPosition`.
  /// - Si aun asi no se puede determinar la ubicacion, retorna `null` para que
  ///   la atencion y el esquema de vacunacion se registren sin interrupcion.
  Future<({double latitude, double longitude})?> getCurrentLocation({
    Duration timeLimit = const Duration(seconds: 4),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] El servicio de ubicacion esta desactivado.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Permiso de ubicacion denegado.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Permiso de ubicacion denegado permanentemente.');
        return null;
      }

      // Intentar obtener la posicion con precision media y timeout estricto.
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: timeLimit,
          ),
        );
        return (latitude: position.latitude, longitude: position.longitude);
      } catch (e) {
        debugPrint('[LocationService] Error o timeout en getCurrentPosition: $e. Intentando getLastKnownPosition...');
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return (latitude: last.latitude, longitude: last.longitude);
        }
        return null;
      }
    } catch (e) {
      debugPrint('[LocationService] Error no capturado en geolocalizacion: $e');
      return null;
    }
  }
}
