import 'package:flutter/foundation.dart';

import '../connection/admin_session.dart';
import 'vaccinator.dart';

/// Consulta online aislada de los controladores y almacenamiento móviles.
class UsersController extends ChangeNotifier {
  UsersController(this.session);

  final AdminSession session;
  List<Vaccinator> users = const [];
  bool isLoading = false;
  String? error;
  bool _disposed = false;

  Future<void> loadUsers({required String institutionId}) async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await session.loadUsers();
      if (_disposed) return;
      users = data.map(Vaccinator.fromJson).toList();
    } catch (_) {
      if (_disposed) return;
      users = const [];
      error = 'No se pudo consultar el personal. Revisa la conexión y tus permisos.';
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<bool> updateStatus(Vaccinator user, String status) async {
    if (isLoading) return false;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final updated = Vaccinator.fromJson(await session.updateUserStatus(user.id, status));
      if (_disposed) return false;
      users = [for (final item in users) if (item.id == user.id) updated else item];
      return true;
    } catch (_) {
      if (!_disposed) {
        error = 'No se confirmó el cambio. Actualiza la lista antes de reintentar.';
      }
      return false;
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
