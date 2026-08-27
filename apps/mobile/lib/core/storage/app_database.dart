import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/catalogs/domain/entities/catalog_entities.dart';

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

  /// Perfil ampliado del personal de salud (nullable por compatibilidad con
  /// usuarios creados antes de la migracion V4).
  TextColumn get documentType => text().nullable()();

  TextColumn get documentNumber => text().nullable()();

  TextColumn get phone => text().nullable()();

  /// Fecha de nacimiento en formato ISO (yyyy-MM-dd).
  TextColumn get birthDate => text().nullable()();

  TextColumn get gender => text().nullable()();

  TextColumn get professionCode => text().nullable()();

  TextColumn get professionalRegistrationNumber => text().nullable()();

  TextColumn get professionalRegistrationType => text().nullable()();

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

class VaccinesCache extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get category => text()();
  IntColumn get maxDoses => integer()();
  IntColumn get minAgeMonths => integer().nullable()();
  IntColumn get maxAgeMonths => integer().nullable()();
  BoolColumn get active => boolean()();
  IntColumn get version => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Cache global de opciones clinicas (no tiene alcance institucional).
class VaccineOptionsCache extends Table {
  TextColumn get id => text()();
  TextColumn get vaccineId => text()();
  TextColumn get fieldType => text()();
  TextColumn get value => text()();
  TextColumn get displayName => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDefault => boolean()();
  BoolColumn get isActive => boolean()();
  TextColumn get sourceTemplateId => text().nullable()();
  IntColumn get version => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Cache de la relacion vacuna-institucion. Todas las operaciones se acotan
/// por institutionId para evitar contaminar otra institucion.
class InstitutionVaccinesCache extends Table {
  TextColumn get id => text()();
  TextColumn get institutionId => text()();
  TextColumn get vaccineId => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get category => text()();
  BoolColumn get enabled => boolean()();
  IntColumn get version => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Cache de opciones locales, aislado por institucion y vacuna.
class InstitutionVaccineOptionsCache extends Table {
  TextColumn get id => text()();
  TextColumn get institutionId => text()();
  TextColumn get vaccineId => text()();
  TextColumn get fieldType => text()();
  TextColumn get value => text()();
  TextColumn get displayName => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDefault => boolean()();
  BoolColumn get isActive => boolean()();
  TextColumn get sourceTemplateId => text().nullable()();
  IntColumn get version => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    CurrentUser,
    InstitutionsCache,
    UsersCache,
    SyncMetadata,
    VaccinesCache,
    VaccineOptionsCache,
    InstitutionVaccinesCache,
    InstitutionVaccineOptionsCache,
  ],
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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // V2: perfil ampliado del personal de salud (columnas nullables).
        await m.addColumn(usersCache, usersCache.documentType);
        await m.addColumn(usersCache, usersCache.documentNumber);
        await m.addColumn(usersCache, usersCache.phone);
        await m.addColumn(usersCache, usersCache.birthDate);
        await m.addColumn(usersCache, usersCache.gender);
        await m.addColumn(usersCache, usersCache.professionCode);
        await m.addColumn(
          usersCache,
          usersCache.professionalRegistrationNumber,
        );
        await m.addColumn(usersCache, usersCache.professionalRegistrationType);
      }
      if (from < 3) await m.createTable(vaccinesCache);
      if (from < 4) {
        await m.createTable(vaccineOptionsCache);
        await m.createTable(institutionVaccinesCache);
        await m.createTable(institutionVaccineOptionsCache);
      }
    },
  );

  // ---------- UsersCache ----------

  Future<void> upsertUser({
    required String id,
    required String email,
    required String fullName,
    required String institutionId,
    required List<String> roles,
    required String status,
    String? documentType,
    String? documentNumber,
    String? phone,
    String? birthDate,
    String? gender,
    String? professionCode,
    String? professionalRegistrationNumber,
    String? professionalRegistrationType,
  }) {
    return into(usersCache).insertOnConflictUpdate(
      UsersCacheCompanion.insert(
        id: id,
        email: email,
        fullName: fullName,
        institutionId: institutionId,
        roles: jsonEncode(roles),
        status: status,
        documentType: Value(documentType),
        documentNumber: Value(documentNumber),
        phone: Value(phone),
        birthDate: Value(birthDate),
        gender: Value(gender),
        professionCode: Value(professionCode),
        professionalRegistrationNumber: Value(professionalRegistrationNumber),
        professionalRegistrationType: Value(professionalRegistrationType),
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

  Future<void> replaceVaccineCache(List<Vaccine> vaccines) async {
    await transaction(() async {
      await delete(vaccinesCache).go();
      for (final vaccine in vaccines) {
        await into(vaccinesCache).insert(
          VaccinesCacheCompanion.insert(
            id: vaccine.id,
            name: vaccine.name,
            code: vaccine.code,
            category: vaccine.category,
            maxDoses: vaccine.maxDoses,
            minAgeMonths: Value(vaccine.minAgeMonths),
            maxAgeMonths: Value(vaccine.maxAgeMonths),
            active: vaccine.active,
            version: vaccine.version,
          ),
        );
      }
    });
  }

  Future<List<VaccinesCacheData>> cachedVaccines() =>
      select(vaccinesCache).get();

  Future<void> replaceGlobalOptions(
    String vaccineId,
    List<VaccineOption> options,
  ) async {
    await transaction(() async {
      await (delete(
        vaccineOptionsCache,
      )..where((t) => t.vaccineId.equals(vaccineId))).go();
      for (final option in options) {
        await into(vaccineOptionsCache).insert(
          VaccineOptionsCacheCompanion.insert(
            id: option.id,
            vaccineId: vaccineId,
            fieldType: option.fieldType,
            value: option.value,
            displayName: option.displayName,
            sortOrder: option.sortOrder,
            isDefault: option.isDefault,
            isActive: option.isActive,
            sourceTemplateId: Value(option.sourceTemplateId),
            version: option.version,
          ),
        );
      }
    });
  }

  Future<List<VaccineOptionsCacheData>> cachedGlobalOptions(String vaccineId) =>
      (select(
        vaccineOptionsCache,
      )..where((t) => t.vaccineId.equals(vaccineId))).get();

  Future<void> replaceInstitutionVaccines(
    String institutionId,
    List<InstitutionVaccine> relations,
  ) async {
    await transaction(() async {
      await (delete(
        institutionVaccinesCache,
      )..where((t) => t.institutionId.equals(institutionId))).go();
      for (final relation in relations) {
        await into(institutionVaccinesCache).insert(
          InstitutionVaccinesCacheCompanion.insert(
            id:
                relation.id ??
                '${relation.institutionId}:${relation.vaccineId}',
            institutionId: relation.institutionId,
            vaccineId: relation.vaccineId,
            name: relation.name,
            code: relation.code,
            category: relation.category,
            enabled: relation.enabled,
            version: relation.version,
          ),
        );
      }
    });
  }

  Future<List<InstitutionVaccinesCacheData>> cachedInstitutionVaccines(
    String institutionId,
  ) => (select(
    institutionVaccinesCache,
  )..where((t) => t.institutionId.equals(institutionId))).get();

  Future<void> replaceInstitutionOptions(
    String institutionId,
    String vaccineId,
    List<VaccineOption> options,
  ) async {
    await transaction(() async {
      await (delete(institutionVaccineOptionsCache)..where(
            (t) =>
                t.institutionId.equals(institutionId) &
                t.vaccineId.equals(vaccineId),
          ))
          .go();
      for (final option in options) {
        await into(institutionVaccineOptionsCache).insert(
          InstitutionVaccineOptionsCacheCompanion.insert(
            id: option.id,
            institutionId: institutionId,
            vaccineId: vaccineId,
            fieldType: option.fieldType,
            value: option.value,
            displayName: option.displayName,
            sortOrder: option.sortOrder,
            isDefault: option.isDefault,
            isActive: option.isActive,
            sourceTemplateId: Value(option.sourceTemplateId),
            version: option.version,
          ),
        );
      }
    });
  }

  Future<List<InstitutionVaccineOptionsCacheData>> cachedInstitutionOptions(
    String institutionId,
    String vaccineId,
  ) =>
      (select(institutionVaccineOptionsCache)..where(
            (t) =>
                t.institutionId.equals(institutionId) &
                t.vaccineId.equals(vaccineId),
          ))
          .get();
}
