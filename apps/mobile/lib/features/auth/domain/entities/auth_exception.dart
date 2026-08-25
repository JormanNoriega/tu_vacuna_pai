/// Error de autenticacion visible para el usuario (credenciales invalidas,
/// usuario desactivado, perfil sin configurar, red, etc.).
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}