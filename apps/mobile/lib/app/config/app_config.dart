import 'package:flutter/foundation.dart';

/// Configuracion de la aplicacion a partir de variables de compilacion.
///
/// Se inyectan con `--dart-define`:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///               --dart-define=API_BASE_URL=...
///
/// Los valores por defecto apuntan al proyecto Supabase configurado y al backend
/// de Render. En el emulador de Android, `localhost` se traduce a `10.0.2.2`
/// cuando se configura un backend local.
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jfxkrznzhfvecaaixkjv.supabase.co',
  );

  /// Clave publica de Supabase (publishable key, formato `sb_publishable_...`).
  /// No es secreta, pero se inyecta en compilacion para no versionarla como
  /// constante del codigo fuente. El valor por defecto corresponde al proyecto
  /// de desarrollo y se usa cuando no se pasa `--dart-define`.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ysbOoESQ9JpNfa3YS3cnfg_ys4oKnL1',
  );

  /// URL base del API. En Android emulador se traduce `localhost` a `10.0.2.2`.
  /// `API_BASE_URL` permite cambiar el destino en cualquier modo de compilacion.
  static String get apiBaseUrl {
    final configured = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://tu-vacuna-pai.onrender.com/api/v1',
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return configured.replaceFirst('localhost', '10.0.2.2');
    }
    return configured;
  }
}
