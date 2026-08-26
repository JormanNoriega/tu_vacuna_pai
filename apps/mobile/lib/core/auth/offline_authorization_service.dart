/// Estado de autorizacion offline de la sesion local (ADR-003 / ADR-005).
enum OfflineAuthorizationState {
  /// El usuario puede seguir trabajando offline dentro de la ventana.
  authorized,

  /// La ventana offline vencio: solo lectura local, sin nuevas operaciones.
  expired,

  /// No existe perfil local previo: se necesita una validacion online.
  noProfile,
}

/// Evalua la ventana de autorizacion offline.
///
/// La politica es propia de la aplicacion y NO depende de la expiracion del
/// access token de Supabase: el criterio es exclusivamente
/// `now - lastOnlineValidation <= offlineWindowHours`.
class OfflineAuthorizationService {
  const OfflineAuthorizationService();

  OfflineAuthorizationState evaluate({
    DateTime? lastOnlineValidation,
    required int offlineWindowHours,
    DateTime? now,
  }) {
    final last = lastOnlineValidation;
    if (last == null) return OfflineAuthorizationState.noProfile;

    final current = now ?? DateTime.now();
    final elapsedHours = current.difference(last).inHours;
    if (elapsedHours <= offlineWindowHours) {
      return OfflineAuthorizationState.authorized;
    }
    return OfflineAuthorizationState.expired;
  }
}