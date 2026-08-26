import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Estado de sesion local persistido de forma segura (secretos y metadatos de
/// autorizacion offline). Los tokens nunca viven en SQLite.
class SessionData {
  const SessionData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.lastOnlineValidation,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final DateTime lastOnlineValidation;
}

class SessionManager {
  SessionManager(this._storage);

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'session_expires_at';
  static const _lastOnlineKey = 'last_online_validation';

  final FlutterSecureStorage _storage;

  Future<void> saveSession(SessionData session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(
        key: _expiresAtKey,
        value: session.expiresAt.toIso8601String(),
      ),
      _storage.write(
        key: _lastOnlineKey,
        value: session.lastOnlineValidation.toIso8601String(),
      ),
    ]);
  }

  Future<SessionData?> loadSession() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return null;

    final refreshToken = await _storage.read(key: _refreshTokenKey) ?? '';
    final expiresAtRaw = await _storage.read(key: _expiresAtKey);
    final lastOnlineRaw = await _storage.read(key: _lastOnlineKey);

    return SessionData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAtRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(expiresAtRaw),
      lastOnlineValidation: lastOnlineRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(lastOnlineRaw),
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
      _storage.delete(key: _lastOnlineKey),
    ]);
  }
}
