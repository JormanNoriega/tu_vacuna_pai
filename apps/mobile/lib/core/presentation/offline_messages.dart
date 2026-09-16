import '../../features/auth/domain/entities/session_restore_result.dart';
import '../auth/offline_access.dart';
import '../network/api_exception.dart';

/// Mensajes coherentes para el trabajo sin conexion.
///
/// Centraliza el texto que se muestra cuando la red no esta disponible, para no
/// exponer errores de transporte crudos ("No se pudo conectar con el servidor")
/// cuando la app esta operando en local-first y el dato ya quedo guardado.
abstract final class OfflineMessages {
  const OfflineMessages._();

  /// True si la sesion trabaja en la ventana offline (sin validacion online).
  static bool isOffline(OfflineAccess offline) =>
      offline.status != SessionStatus.signedIn;

  /// Un registro generico quedo guardado en el dispositivo.
  static const saved =
      'Sin conexion: el registro quedo guardado en el dispositivo y se '
      'subira cuando vuelva la red.';

  /// La atencion quedo guardada y se sincronizara sola.
  static const savedAttention =
      'Sin conexion: la atencion quedo guardada en el dispositivo y se '
      'sincronizara cuando vuelva la red.';

  /// Aun hay registros pendientes por subir.
  static const pendingSync =
      'Sin conexion: tus registros siguen guardados y se subiran '
      'automaticamente cuando vuelva la red.';

  /// True si [error] corresponde a un fallo de transporte (sin servidor/red),
  /// en lugar de un rechazo de negocio de la API.
  static bool isConnectionError(ApiException error) =>
      error.statusCode == null &&
      (error.message.contains('No se pudo conectar') ||
          error.message.contains('no respondio a tiempo'));

  /// Traduce un fallo de conexion a un mensaje coherente con el estado actual.
  static String forConnectionError(OfflineAccess offline) => isOffline(offline)
      ? saved
      : 'No hay conexion con el servidor. Intenta de nuevo en un momento.';
}
