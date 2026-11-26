import 'package:flutter/foundation.dart';

import '../../core/auth/session_manager.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

class GeographyCell {
  const GeographyCell(this.latitude, this.longitude, this.count);
  final double latitude;
  final double longitude;
  final int count;
}

class GeographyData {
  const GeographyData(this.generatedAt, this.cells);
  final DateTime generatedAt;
  final List<GeographyCell> cells;

  factory GeographyData.fromJson(Map<String, dynamic> json) => GeographyData(
    DateTime.parse(json['generatedAt'] as String),
    List.unmodifiable(
      (json['cells'] as List).map((value) {
        final row = value as Map<String, dynamic>;
        return GeographyCell(
          (row['latitude'] as num).toDouble(),
          (row['longitude'] as num).toDouble(),
          (row['count'] as num).toInt(),
        );
      }),
    ),
  );
}

class GeographyController extends ChangeNotifier {
  GeographyController({
    required this.api,
    required this.sessionManager,
    this.synthetic = false,
  });
  final ApiClient api;
  final SessionManager sessionManager;
  final bool synthetic;
  final _cache = <int, (DateTime, GeographyData)>{};
  GeographyData? data;
  String? error;
  bool loading = false;
  int _generation = 0;

  Future<void> load(int days, {bool refresh = false}) async {
    final generation = ++_generation;
    if (synthetic) {
      // Ejemplo fijo, generado únicamente en memoria; no representa atenciones reales.
      final multiplier = switch (days) {
        7 => 1,
        30 => 2,
        90 => 4,
        _ => 1,
      };
      data = GeographyData(DateTime.now(), [
        GeographyCell(4.65, -74.09, 8 * multiplier),
        GeographyCell(4.67, -74.11, 6 * multiplier),
        GeographyCell(4.63, -74.08, 12 * multiplier),
        GeographyCell(4.69, -74.07, 5 * multiplier),
        GeographyCell(4.61, -74.12, 7 * multiplier),
        GeographyCell(4.71, -74.04, 9 * multiplier),
        GeographyCell(4.58, -74.15, 5 * multiplier),
      ]);
      error = null;
      loading = false;
      notifyListeners();
      return;
    }
    final cached = _cache[days];
    data = null;
    error = null;
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 5)) {
      data = cached.$2;
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final session = await sessionManager.loadSession();
      if (session == null) throw StateError('Sesión no disponible');
      final result = GeographyData.fromJson(
        await api.fetchGeography(session.accessToken, days),
      );
      if (generation != _generation) return;
      _cache[days] = (DateTime.now(), result);
      data = result;
    } on ApiException catch (exception) {
      if (generation != _generation) return;
      error = exception.statusCode == 404
          ? 'El servicio geográfico no está disponible en este entorno.'
          : 'No se pudo cargar el visor. Comprueba la conexión y vuelve a intentarlo.';
    } catch (_) {
      if (generation != _generation) return;
      error = 'No se pudo cargar el visor. Comprueba la conexión y vuelve a intentarlo.';
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void clearSession() {
    _generation++;
    _cache.clear();
    data = null;
    error = null;
    loading = false;
    notifyListeners();
  }
}
