import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/entities/auth_user.dart';

/// Persiste el perfil autorizado (RemoteUserProfile) y su institucion en la
/// base local Drift. No es secreto: los tokens y secretos viven exclusivamente
/// en almacenamiento seguro (ADR-005).
class LocalSessionStore {
  LocalSessionStore(this._database);

  final AppDatabase _database;

  Future<void> saveProfile(AuthUser user) async {
    await _database.upsertCurrentUser(
      id: user.id,
      email: user.email,
      fullName: user.name,
      institutionId: user.institution.id,
      roles: user.roles,
      permissions: user.permissions,
      offlineWindowHours: user.offlineWindowHours,
      lastOnlineValidation: user.lastOnlineValidation
          .toUtc()
          .millisecondsSinceEpoch ~/
          1000,
    );
    await _database.upsertInstitution(
      id: user.institution.id,
      code: user.institution.code,
      name: user.institution.name,
      offlineWindowHours: user.offlineWindowHours,
      status: 'ACTIVE',
    );
  }

  Future<AuthUser?> loadProfile() async {
    final profile = await _database.currentUserProfile();
    if (profile == null) return null;

    final institution = await _database.institutionById(profile.institutionId);
    if (institution == null) return null;

    return AuthUser(
      id: profile.id,
      email: profile.email,
      name: profile.fullName,
      institution: InstitutionProfile(
        id: institution.id,
        code: institution.code,
        name: institution.name,
      ),
      roles: _decodeList(profile.roles),
      permissions: _decodeList(profile.permissions),
      offlineWindowHours: profile.offlineWindowHours,
      lastOnlineValidation: DateTime.fromMillisecondsSinceEpoch(
        profile.lastOnlineValidation * 1000,
        isUtc: true,
      ),
    );
  }

  Future<void> clearProfile() => _database.clearCurrentUser();

  static List<String> _decodeList(String json) =>
      (jsonDecode(json) as List<dynamic>).cast<String>();
}