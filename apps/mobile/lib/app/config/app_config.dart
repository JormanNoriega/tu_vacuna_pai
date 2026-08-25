/// Configuracion de la aplicacion a partir de variables de compilacion.
///
/// Se inyectan con `--dart-define`:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///               --dart-define=API_BASE_URL=...
///
/// Los valores por defecto apuntan al proyecto Supabase y a un backend local.
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jfxkrznzhfvecaaixkjv.supabase.co',
  );

  /// Clave publica de Supabase (publishable key, formato `sb_publishable_...`).
  /// No es secreta, pero se inyecta en compilacion para no versionarla como
  /// constante del codigo fuente. Acepta la clave anon legacy como respaldo.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );
}