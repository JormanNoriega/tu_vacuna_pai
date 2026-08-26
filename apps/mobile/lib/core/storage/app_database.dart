import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'app_database.g.dart';

/// Perfil del usuario autenticado que se persiste localmente. No es secreto:
/// roles, permisos y metadatos de la ventana offline (ADR-005). Los tokens
/// siguen viviendo exclusivamente en almacenamiento seguro.
class CurrentUser extends Table {
  TextColumn get id => text()();

  TextColumn get email => text()();

  TextColumn get fullName => text()();

  TextColumn get institutionId => text()();

  /// JSON con la lista de roles.
  TextColumn get roles => text()();

  /// JSON con la lista de permisos.
  TextColumn get permissions => text()();

  IntColumn get offlineWindowHours => integer()();

  /// Epoch (segundos) de la ultima validacion online.
  IntColumn get lastOnlineValidation => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache local de instituciones para consulta sin red.
class InstitutionsCache extends Table {
  TextColumn get id => text()();

  TextColumn get code => text()();

  TextColumn get name => text()();

  IntColumn get offlineWindowHours => integer()();

  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache local de los usuarios de una institucion (ADMIN_INSTITUTION).
class UsersCache extends Table {
  TextColumn get id => text()();

  TextColumn get email => text()();

  TextColumn get fullName => text()();

  TextColumn get institutionId => text()();

  /// JSON con la lista de roles.
  TextColumn get roles => text()();

  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metadatos de sincronizacion (cursor, ultima validacion, etc.).
class SyncMetadata extends Table {
  TextColumn get key => text().named('key')();

  TextColumn get value => text().named('value')();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [CurrentUser, InstitutionsCache, UsersCache, SyncMetadata],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Abre la base local con la implementacion nativa de drift_flutter.
  ///
  /// La base queda cifrada con SQLite3MultipleCiphers (compatible SQLCipher):
  /// el binario nativo se resuelve con `hooks.user_defines.sqlite3.source =
  /// sqlite3mc` en pubspec.yaml (ADR-003). La clave se genera una vez y se
  /// guarda en almacenamiento seguro, nunca en la base.
  ///
  /// Advertencia de migracion: una base creada SIN cifrado por un build
  /// anterior no puede abrirse con clave. Como esta base es solo cache (perfil,
  /// instituciones y usuarios, recreables con una validacion online), la
  /// solucion es eliminar el archivo local (o reinstalar) antes del primer
  /// arranque con cifrado.
  static Future<AppDatabase> open(FlutterSecureStorage storage) async {
    final key = await _loadOrCreateKey(storage);
    final connection = driftDatabase(
      name: 'tu_vacuna_pai',
      native: DriftNativeOptions(
        setup: (raw) {
          raw.execute("PRAGMA key = '$key'");
          // SQLite3MultipleCiphers exige este pragma para abrir bases SQLCipher.
          raw.execute('PRAGMA cipher_memory_security = OFF');
        },
      ),
    );
    return AppDatabase(connection);
  }

  static const _databaseKeyName = 'local_db_key';

  static Future<String> _loadOrCreateKey(FlutterSecureStorage storage) async {
    final existing = await storage.read(key: _databaseKeyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await storage.write(key: _databaseKeyName, value: key);
    return key;
  }

  @override
  int get schemaVersion => 1;

  // ---------- UsersCache ----------

  Future<void> upsertUser({
    required String id,
    required String email,
    required String fullName,
    required String institutionId,
    required List<String> roles,
    required String status,
  }) {
    return into(usersCache).insertOnConflictUpdate(
      UsersCacheCompanion.insert(
        id: id,
        email: email,
        fullName: fullName,
        institutionId: institutionId,
        roles: jsonEncode(roles),
        status: status,
      ),
    );
  }

  Future<List<UsersCacheData>> usersByInstitution(String institutionId) {
    return (select(
      usersCache,
    )..where((t) => t.institutionId.equals(institutionId))).get();
  }

  // ---------- InstitutionsCache ----------

  Future<void> upsertInstitution({
    required String id,
    required String code,
    required String name,
    required int offlineWindowHours,
    required String status,
  }) {
    return into(institutionsCache).insertOnConflictUpdate(
      InstitutionsCacheCompanion.insert(
        id: id,
        code: code,
        name: name,
        offlineWindowHours: offlineWindowHours,
        status: status,
      ),
    );
  }

  Future<InstitutionsCacheData?> institutionById(String id) {
    return (select(
      institutionsCache,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ---------- CurrentUser ----------

  Future<void> upsertCurrentUser({
    required String id,
    required String email,
    required String fullName,
    required String institutionId,
    required List<String> roles,
    required List<String> permissions,
    required int offlineWindowHours,
    required int lastOnlineValidation,
  }) {
    return into(currentUser).insertOnConflictUpdate(
      CurrentUserCompanion.insert(
        id: id,
        email: email,
        fullName: fullName,
        institutionId: institutionId,
        roles: jsonEncode(roles),
        permissions: jsonEncode(permissions),
        offlineWindowHours: offlineWindowHours,
        lastOnlineValidation: lastOnlineValidation,
      ),
    );
  }

  Future<CurrentUserData?> currentUserProfile() {
    return (select(currentUser)..limit(1)).getSingleOrNull();
  }

  Future<void> clearCurrentUser() => delete(currentUser).go();

  // ---------- SyncMetadata ----------

  Future<void> setSyncMetadata(String key, String value) {
    return into(syncMetadata).insertOnConflictUpdate(
      SyncMetadataCompanion.insert(key: key, value: value),
    );
  }

  Future<String?> syncMetadataValue(String key) async {
    final row = await (select(
      syncMetadata,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
