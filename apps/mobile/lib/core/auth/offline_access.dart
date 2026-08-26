import '../../features/auth/domain/entities/session_restore_result.dart';

/// Instantanea del estado de sesion que las operaciones de escritura consultan
/// antes de ejecutarse. Se resuelve en la UI (perfil del usuario autenticado +
/// estado de la sesion) y se propaga hasta el caso de uso, que aplica la
/// politica offline.
class OfflineAccess {
  const OfflineAccess({required this.status, required this.permissions});

  /// Estado actual de la sesion (online, offline autorizado o bloqueado).
  final SessionStatus status;

  /// Permisos vigentes del usuario autenticado.
  final List<String> permissions;
}
