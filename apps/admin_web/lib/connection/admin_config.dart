/// Configuración pública del navegador; nunca incluir claves privilegiadas.
class AdminConfig {
  AdminConfig._(this.supabaseUrl, this.publishableKey, this.apiBaseUrl);

  final Uri supabaseUrl;
  final String publishableKey;
  final Uri apiBaseUrl;

  factory AdminConfig.fromValues({
    required String supabaseUrl,
    required String publishableKey,
    required String apiBaseUrl,
  }) {
    Uri parseUrl(String value, String name) {
      final uri = Uri.tryParse(value.trim());
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.scheme != 'https' &&
              !(uri.scheme == 'http' &&
                  (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
        throw FormatException('$name debe ser HTTPS o HTTP en localhost.');
      }
      return uri;
    }

    final key = publishableKey.trim();
    if (!key.startsWith('sb_publishable_') || key.length <= 15) {
      throw const FormatException('Se requiere una clave publishable pública.');
    }
    return AdminConfig._(
      parseUrl(supabaseUrl, 'SUPABASE_URL'),
      key,
      parseUrl(apiBaseUrl, 'API_BASE_URL'),
    );
  }

  factory AdminConfig.fromEnvironment() => AdminConfig.fromValues(
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
  );
}
