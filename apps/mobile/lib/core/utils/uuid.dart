import 'dart:math';

/// Genera un UUID v4 (RFC 4122) sin dependencias externas.
///
/// Se usa como clave de idempotencia del aprovisionamiento de usuarios
/// (`operationId`): se genera por intencion de creacion y se reenvia en
/// reintentos para que el backend no duplique.
String uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
