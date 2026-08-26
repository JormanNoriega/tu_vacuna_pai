// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CurrentUserTable extends CurrentUser
    with TableInfo<$CurrentUserTable, CurrentUserData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrentUserTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionIdMeta = const VerificationMeta(
    'institutionId',
  );
  @override
  late final GeneratedColumn<String> institutionId = GeneratedColumn<String>(
    'institution_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rolesMeta = const VerificationMeta('roles');
  @override
  late final GeneratedColumn<String> roles = GeneratedColumn<String>(
    'roles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _permissionsMeta = const VerificationMeta(
    'permissions',
  );
  @override
  late final GeneratedColumn<String> permissions = GeneratedColumn<String>(
    'permissions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offlineWindowHoursMeta =
      const VerificationMeta('offlineWindowHours');
  @override
  late final GeneratedColumn<int> offlineWindowHours = GeneratedColumn<int>(
    'offline_window_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOnlineValidationMeta =
      const VerificationMeta('lastOnlineValidation');
  @override
  late final GeneratedColumn<int> lastOnlineValidation = GeneratedColumn<int>(
    'last_online_validation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    fullName,
    institutionId,
    roles,
    permissions,
    offlineWindowHours,
    lastOnlineValidation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'current_user';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurrentUserData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('institution_id')) {
      context.handle(
        _institutionIdMeta,
        institutionId.isAcceptableOrUnknown(
          data['institution_id']!,
          _institutionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionIdMeta);
    }
    if (data.containsKey('roles')) {
      context.handle(
        _rolesMeta,
        roles.isAcceptableOrUnknown(data['roles']!, _rolesMeta),
      );
    } else if (isInserting) {
      context.missing(_rolesMeta);
    }
    if (data.containsKey('permissions')) {
      context.handle(
        _permissionsMeta,
        permissions.isAcceptableOrUnknown(
          data['permissions']!,
          _permissionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_permissionsMeta);
    }
    if (data.containsKey('offline_window_hours')) {
      context.handle(
        _offlineWindowHoursMeta,
        offlineWindowHours.isAcceptableOrUnknown(
          data['offline_window_hours']!,
          _offlineWindowHoursMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_offlineWindowHoursMeta);
    }
    if (data.containsKey('last_online_validation')) {
      context.handle(
        _lastOnlineValidationMeta,
        lastOnlineValidation.isAcceptableOrUnknown(
          data['last_online_validation']!,
          _lastOnlineValidationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOnlineValidationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CurrentUserData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrentUserData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      institutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_id'],
      )!,
      roles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roles'],
      )!,
      permissions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permissions'],
      )!,
      offlineWindowHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offline_window_hours'],
      )!,
      lastOnlineValidation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_online_validation'],
      )!,
    );
  }

  @override
  $CurrentUserTable createAlias(String alias) {
    return $CurrentUserTable(attachedDatabase, alias);
  }
}

class CurrentUserData extends DataClass implements Insertable<CurrentUserData> {
  final String id;
  final String email;
  final String fullName;
  final String institutionId;

  /// JSON con la lista de roles.
  final String roles;

  /// JSON con la lista de permisos.
  final String permissions;
  final int offlineWindowHours;

  /// Epoch (segundos) de la ultima validacion online.
  final int lastOnlineValidation;
  const CurrentUserData({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institutionId,
    required this.roles,
    required this.permissions,
    required this.offlineWindowHours,
    required this.lastOnlineValidation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['full_name'] = Variable<String>(fullName);
    map['institution_id'] = Variable<String>(institutionId);
    map['roles'] = Variable<String>(roles);
    map['permissions'] = Variable<String>(permissions);
    map['offline_window_hours'] = Variable<int>(offlineWindowHours);
    map['last_online_validation'] = Variable<int>(lastOnlineValidation);
    return map;
  }

  CurrentUserCompanion toCompanion(bool nullToAbsent) {
    return CurrentUserCompanion(
      id: Value(id),
      email: Value(email),
      fullName: Value(fullName),
      institutionId: Value(institutionId),
      roles: Value(roles),
      permissions: Value(permissions),
      offlineWindowHours: Value(offlineWindowHours),
      lastOnlineValidation: Value(lastOnlineValidation),
    );
  }

  factory CurrentUserData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrentUserData(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      fullName: serializer.fromJson<String>(json['fullName']),
      institutionId: serializer.fromJson<String>(json['institutionId']),
      roles: serializer.fromJson<String>(json['roles']),
      permissions: serializer.fromJson<String>(json['permissions']),
      offlineWindowHours: serializer.fromJson<int>(json['offlineWindowHours']),
      lastOnlineValidation: serializer.fromJson<int>(
        json['lastOnlineValidation'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'fullName': serializer.toJson<String>(fullName),
      'institutionId': serializer.toJson<String>(institutionId),
      'roles': serializer.toJson<String>(roles),
      'permissions': serializer.toJson<String>(permissions),
      'offlineWindowHours': serializer.toJson<int>(offlineWindowHours),
      'lastOnlineValidation': serializer.toJson<int>(lastOnlineValidation),
    };
  }

  CurrentUserData copyWith({
    String? id,
    String? email,
    String? fullName,
    String? institutionId,
    String? roles,
    String? permissions,
    int? offlineWindowHours,
    int? lastOnlineValidation,
  }) => CurrentUserData(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    institutionId: institutionId ?? this.institutionId,
    roles: roles ?? this.roles,
    permissions: permissions ?? this.permissions,
    offlineWindowHours: offlineWindowHours ?? this.offlineWindowHours,
    lastOnlineValidation: lastOnlineValidation ?? this.lastOnlineValidation,
  );
  CurrentUserData copyWithCompanion(CurrentUserCompanion data) {
    return CurrentUserData(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      institutionId: data.institutionId.present
          ? data.institutionId.value
          : this.institutionId,
      roles: data.roles.present ? data.roles.value : this.roles,
      permissions: data.permissions.present
          ? data.permissions.value
          : this.permissions,
      offlineWindowHours: data.offlineWindowHours.present
          ? data.offlineWindowHours.value
          : this.offlineWindowHours,
      lastOnlineValidation: data.lastOnlineValidation.present
          ? data.lastOnlineValidation.value
          : this.lastOnlineValidation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrentUserData(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('fullName: $fullName, ')
          ..write('institutionId: $institutionId, ')
          ..write('roles: $roles, ')
          ..write('permissions: $permissions, ')
          ..write('offlineWindowHours: $offlineWindowHours, ')
          ..write('lastOnlineValidation: $lastOnlineValidation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    fullName,
    institutionId,
    roles,
    permissions,
    offlineWindowHours,
    lastOnlineValidation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrentUserData &&
          other.id == this.id &&
          other.email == this.email &&
          other.fullName == this.fullName &&
          other.institutionId == this.institutionId &&
          other.roles == this.roles &&
          other.permissions == this.permissions &&
          other.offlineWindowHours == this.offlineWindowHours &&
          other.lastOnlineValidation == this.lastOnlineValidation);
}

class CurrentUserCompanion extends UpdateCompanion<CurrentUserData> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> fullName;
  final Value<String> institutionId;
  final Value<String> roles;
  final Value<String> permissions;
  final Value<int> offlineWindowHours;
  final Value<int> lastOnlineValidation;
  final Value<int> rowid;
  const CurrentUserCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.fullName = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.roles = const Value.absent(),
    this.permissions = const Value.absent(),
    this.offlineWindowHours = const Value.absent(),
    this.lastOnlineValidation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrentUserCompanion.insert({
    required String id,
    required String email,
    required String fullName,
    required String institutionId,
    required String roles,
    required String permissions,
    required int offlineWindowHours,
    required int lastOnlineValidation,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       fullName = Value(fullName),
       institutionId = Value(institutionId),
       roles = Value(roles),
       permissions = Value(permissions),
       offlineWindowHours = Value(offlineWindowHours),
       lastOnlineValidation = Value(lastOnlineValidation);
  static Insertable<CurrentUserData> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? fullName,
    Expression<String>? institutionId,
    Expression<String>? roles,
    Expression<String>? permissions,
    Expression<int>? offlineWindowHours,
    Expression<int>? lastOnlineValidation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (fullName != null) 'full_name': fullName,
      if (institutionId != null) 'institution_id': institutionId,
      if (roles != null) 'roles': roles,
      if (permissions != null) 'permissions': permissions,
      if (offlineWindowHours != null)
        'offline_window_hours': offlineWindowHours,
      if (lastOnlineValidation != null)
        'last_online_validation': lastOnlineValidation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrentUserCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? fullName,
    Value<String>? institutionId,
    Value<String>? roles,
    Value<String>? permissions,
    Value<int>? offlineWindowHours,
    Value<int>? lastOnlineValidation,
    Value<int>? rowid,
  }) {
    return CurrentUserCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      institutionId: institutionId ?? this.institutionId,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      offlineWindowHours: offlineWindowHours ?? this.offlineWindowHours,
      lastOnlineValidation: lastOnlineValidation ?? this.lastOnlineValidation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (institutionId.present) {
      map['institution_id'] = Variable<String>(institutionId.value);
    }
    if (roles.present) {
      map['roles'] = Variable<String>(roles.value);
    }
    if (permissions.present) {
      map['permissions'] = Variable<String>(permissions.value);
    }
    if (offlineWindowHours.present) {
      map['offline_window_hours'] = Variable<int>(offlineWindowHours.value);
    }
    if (lastOnlineValidation.present) {
      map['last_online_validation'] = Variable<int>(lastOnlineValidation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrentUserCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('fullName: $fullName, ')
          ..write('institutionId: $institutionId, ')
          ..write('roles: $roles, ')
          ..write('permissions: $permissions, ')
          ..write('offlineWindowHours: $offlineWindowHours, ')
          ..write('lastOnlineValidation: $lastOnlineValidation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstitutionsCacheTable extends InstitutionsCache
    with TableInfo<$InstitutionsCacheTable, InstitutionsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstitutionsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offlineWindowHoursMeta =
      const VerificationMeta('offlineWindowHours');
  @override
  late final GeneratedColumn<int> offlineWindowHours = GeneratedColumn<int>(
    'offline_window_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    offlineWindowHours,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'institutions_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstitutionsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('offline_window_hours')) {
      context.handle(
        _offlineWindowHoursMeta,
        offlineWindowHours.isAcceptableOrUnknown(
          data['offline_window_hours']!,
          _offlineWindowHoursMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_offlineWindowHoursMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstitutionsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstitutionsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      offlineWindowHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offline_window_hours'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $InstitutionsCacheTable createAlias(String alias) {
    return $InstitutionsCacheTable(attachedDatabase, alias);
  }
}

class InstitutionsCacheData extends DataClass
    implements Insertable<InstitutionsCacheData> {
  final String id;
  final String code;
  final String name;
  final int offlineWindowHours;
  final String status;
  const InstitutionsCacheData({
    required this.id,
    required this.code,
    required this.name,
    required this.offlineWindowHours,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['offline_window_hours'] = Variable<int>(offlineWindowHours);
    map['status'] = Variable<String>(status);
    return map;
  }

  InstitutionsCacheCompanion toCompanion(bool nullToAbsent) {
    return InstitutionsCacheCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      offlineWindowHours: Value(offlineWindowHours),
      status: Value(status),
    );
  }

  factory InstitutionsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstitutionsCacheData(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      offlineWindowHours: serializer.fromJson<int>(json['offlineWindowHours']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'offlineWindowHours': serializer.toJson<int>(offlineWindowHours),
      'status': serializer.toJson<String>(status),
    };
  }

  InstitutionsCacheData copyWith({
    String? id,
    String? code,
    String? name,
    int? offlineWindowHours,
    String? status,
  }) => InstitutionsCacheData(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    offlineWindowHours: offlineWindowHours ?? this.offlineWindowHours,
    status: status ?? this.status,
  );
  InstitutionsCacheData copyWithCompanion(InstitutionsCacheCompanion data) {
    return InstitutionsCacheData(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      offlineWindowHours: data.offlineWindowHours.present
          ? data.offlineWindowHours.value
          : this.offlineWindowHours,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstitutionsCacheData(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('offlineWindowHours: $offlineWindowHours, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, name, offlineWindowHours, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstitutionsCacheData &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.offlineWindowHours == this.offlineWindowHours &&
          other.status == this.status);
}

class InstitutionsCacheCompanion
    extends UpdateCompanion<InstitutionsCacheData> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> offlineWindowHours;
  final Value<String> status;
  final Value<int> rowid;
  const InstitutionsCacheCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.offlineWindowHours = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstitutionsCacheCompanion.insert({
    required String id,
    required String code,
    required String name,
    required int offlineWindowHours,
    required String status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       offlineWindowHours = Value(offlineWindowHours),
       status = Value(status);
  static Insertable<InstitutionsCacheData> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? offlineWindowHours,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (offlineWindowHours != null)
        'offline_window_hours': offlineWindowHours,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstitutionsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<int>? offlineWindowHours,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return InstitutionsCacheCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      offlineWindowHours: offlineWindowHours ?? this.offlineWindowHours,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (offlineWindowHours.present) {
      map['offline_window_hours'] = Variable<int>(offlineWindowHours.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstitutionsCacheCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('offlineWindowHours: $offlineWindowHours, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersCacheTable extends UsersCache
    with TableInfo<$UsersCacheTable, UsersCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionIdMeta = const VerificationMeta(
    'institutionId',
  );
  @override
  late final GeneratedColumn<String> institutionId = GeneratedColumn<String>(
    'institution_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rolesMeta = const VerificationMeta('roles');
  @override
  late final GeneratedColumn<String> roles = GeneratedColumn<String>(
    'roles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    fullName,
    institutionId,
    roles,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsersCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('institution_id')) {
      context.handle(
        _institutionIdMeta,
        institutionId.isAcceptableOrUnknown(
          data['institution_id']!,
          _institutionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionIdMeta);
    }
    if (data.containsKey('roles')) {
      context.handle(
        _rolesMeta,
        roles.isAcceptableOrUnknown(data['roles']!, _rolesMeta),
      );
    } else if (isInserting) {
      context.missing(_rolesMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsersCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsersCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      institutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_id'],
      )!,
      roles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roles'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $UsersCacheTable createAlias(String alias) {
    return $UsersCacheTable(attachedDatabase, alias);
  }
}

class UsersCacheData extends DataClass implements Insertable<UsersCacheData> {
  final String id;
  final String email;
  final String fullName;
  final String institutionId;

  /// JSON con la lista de roles.
  final String roles;
  final String status;
  const UsersCacheData({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institutionId,
    required this.roles,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['full_name'] = Variable<String>(fullName);
    map['institution_id'] = Variable<String>(institutionId);
    map['roles'] = Variable<String>(roles);
    map['status'] = Variable<String>(status);
    return map;
  }

  UsersCacheCompanion toCompanion(bool nullToAbsent) {
    return UsersCacheCompanion(
      id: Value(id),
      email: Value(email),
      fullName: Value(fullName),
      institutionId: Value(institutionId),
      roles: Value(roles),
      status: Value(status),
    );
  }

  factory UsersCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsersCacheData(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      fullName: serializer.fromJson<String>(json['fullName']),
      institutionId: serializer.fromJson<String>(json['institutionId']),
      roles: serializer.fromJson<String>(json['roles']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'fullName': serializer.toJson<String>(fullName),
      'institutionId': serializer.toJson<String>(institutionId),
      'roles': serializer.toJson<String>(roles),
      'status': serializer.toJson<String>(status),
    };
  }

  UsersCacheData copyWith({
    String? id,
    String? email,
    String? fullName,
    String? institutionId,
    String? roles,
    String? status,
  }) => UsersCacheData(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    institutionId: institutionId ?? this.institutionId,
    roles: roles ?? this.roles,
    status: status ?? this.status,
  );
  UsersCacheData copyWithCompanion(UsersCacheCompanion data) {
    return UsersCacheData(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      institutionId: data.institutionId.present
          ? data.institutionId.value
          : this.institutionId,
      roles: data.roles.present ? data.roles.value : this.roles,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsersCacheData(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('fullName: $fullName, ')
          ..write('institutionId: $institutionId, ')
          ..write('roles: $roles, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, email, fullName, institutionId, roles, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsersCacheData &&
          other.id == this.id &&
          other.email == this.email &&
          other.fullName == this.fullName &&
          other.institutionId == this.institutionId &&
          other.roles == this.roles &&
          other.status == this.status);
}

class UsersCacheCompanion extends UpdateCompanion<UsersCacheData> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> fullName;
  final Value<String> institutionId;
  final Value<String> roles;
  final Value<String> status;
  final Value<int> rowid;
  const UsersCacheCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.fullName = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.roles = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCacheCompanion.insert({
    required String id,
    required String email,
    required String fullName,
    required String institutionId,
    required String roles,
    required String status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       fullName = Value(fullName),
       institutionId = Value(institutionId),
       roles = Value(roles),
       status = Value(status);
  static Insertable<UsersCacheData> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? fullName,
    Expression<String>? institutionId,
    Expression<String>? roles,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (fullName != null) 'full_name': fullName,
      if (institutionId != null) 'institution_id': institutionId,
      if (roles != null) 'roles': roles,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? fullName,
    Value<String>? institutionId,
    Value<String>? roles,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return UsersCacheCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      institutionId: institutionId ?? this.institutionId,
      roles: roles ?? this.roles,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (institutionId.present) {
      map['institution_id'] = Variable<String>(institutionId.value);
    }
    if (roles.present) {
      map['roles'] = Variable<String>(roles.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCacheCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('fullName: $fullName, ')
          ..write('institutionId: $institutionId, ')
          ..write('roles: $roles, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CurrentUserTable currentUser = $CurrentUserTable(this);
  late final $InstitutionsCacheTable institutionsCache =
      $InstitutionsCacheTable(this);
  late final $UsersCacheTable usersCache = $UsersCacheTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    currentUser,
    institutionsCache,
    usersCache,
    syncMetadata,
  ];
}

typedef $$CurrentUserTableCreateCompanionBuilder =
    CurrentUserCompanion Function({
      required String id,
      required String email,
      required String fullName,
      required String institutionId,
      required String roles,
      required String permissions,
      required int offlineWindowHours,
      required int lastOnlineValidation,
      Value<int> rowid,
    });
typedef $$CurrentUserTableUpdateCompanionBuilder =
    CurrentUserCompanion Function({
      Value<String> id,
      Value<String> email,
      Value<String> fullName,
      Value<String> institutionId,
      Value<String> roles,
      Value<String> permissions,
      Value<int> offlineWindowHours,
      Value<int> lastOnlineValidation,
      Value<int> rowid,
    });

class $$CurrentUserTableFilterComposer
    extends Composer<_$AppDatabase, $CurrentUserTable> {
  $$CurrentUserTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roles => $composableBuilder(
    column: $table.roles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permissions => $composableBuilder(
    column: $table.permissions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offlineWindowHours => $composableBuilder(
    column: $table.offlineWindowHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOnlineValidation => $composableBuilder(
    column: $table.lastOnlineValidation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurrentUserTableOrderingComposer
    extends Composer<_$AppDatabase, $CurrentUserTable> {
  $$CurrentUserTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roles => $composableBuilder(
    column: $table.roles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permissions => $composableBuilder(
    column: $table.permissions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offlineWindowHours => $composableBuilder(
    column: $table.offlineWindowHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOnlineValidation => $composableBuilder(
    column: $table.lastOnlineValidation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurrentUserTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurrentUserTable> {
  $$CurrentUserTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roles =>
      $composableBuilder(column: $table.roles, builder: (column) => column);

  GeneratedColumn<String> get permissions => $composableBuilder(
    column: $table.permissions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offlineWindowHours => $composableBuilder(
    column: $table.offlineWindowHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOnlineValidation => $composableBuilder(
    column: $table.lastOnlineValidation,
    builder: (column) => column,
  );
}

class $$CurrentUserTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurrentUserTable,
          CurrentUserData,
          $$CurrentUserTableFilterComposer,
          $$CurrentUserTableOrderingComposer,
          $$CurrentUserTableAnnotationComposer,
          $$CurrentUserTableCreateCompanionBuilder,
          $$CurrentUserTableUpdateCompanionBuilder,
          (
            CurrentUserData,
            BaseReferences<_$AppDatabase, $CurrentUserTable, CurrentUserData>,
          ),
          CurrentUserData,
          PrefetchHooks Function()
        > {
  $$CurrentUserTableTableManager(_$AppDatabase db, $CurrentUserTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrentUserTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurrentUserTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurrentUserTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> institutionId = const Value.absent(),
                Value<String> roles = const Value.absent(),
                Value<String> permissions = const Value.absent(),
                Value<int> offlineWindowHours = const Value.absent(),
                Value<int> lastOnlineValidation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrentUserCompanion(
                id: id,
                email: email,
                fullName: fullName,
                institutionId: institutionId,
                roles: roles,
                permissions: permissions,
                offlineWindowHours: offlineWindowHours,
                lastOnlineValidation: lastOnlineValidation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String fullName,
                required String institutionId,
                required String roles,
                required String permissions,
                required int offlineWindowHours,
                required int lastOnlineValidation,
                Value<int> rowid = const Value.absent(),
              }) => CurrentUserCompanion.insert(
                id: id,
                email: email,
                fullName: fullName,
                institutionId: institutionId,
                roles: roles,
                permissions: permissions,
                offlineWindowHours: offlineWindowHours,
                lastOnlineValidation: lastOnlineValidation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurrentUserTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurrentUserTable,
      CurrentUserData,
      $$CurrentUserTableFilterComposer,
      $$CurrentUserTableOrderingComposer,
      $$CurrentUserTableAnnotationComposer,
      $$CurrentUserTableCreateCompanionBuilder,
      $$CurrentUserTableUpdateCompanionBuilder,
      (
        CurrentUserData,
        BaseReferences<_$AppDatabase, $CurrentUserTable, CurrentUserData>,
      ),
      CurrentUserData,
      PrefetchHooks Function()
    >;
typedef $$InstitutionsCacheTableCreateCompanionBuilder =
    InstitutionsCacheCompanion Function({
      required String id,
      required String code,
      required String name,
      required int offlineWindowHours,
      required String status,
      Value<int> rowid,
    });
typedef $$InstitutionsCacheTableUpdateCompanionBuilder =
    InstitutionsCacheCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<int> offlineWindowHours,
      Value<String> status,
      Value<int> rowid,
    });

class $$InstitutionsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $InstitutionsCacheTable> {
  $$InstitutionsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offlineWindowHours => $composableBuilder(
    column: $table.offlineWindowHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstitutionsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $InstitutionsCacheTable> {
  $$InstitutionsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offlineWindowHours => $composableBuilder(
    column: $table.offlineWindowHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstitutionsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstitutionsCacheTable> {
  $$InstitutionsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get offlineWindowHours => $composableBuilder(
    column: $table.offlineWindowHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$InstitutionsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstitutionsCacheTable,
          InstitutionsCacheData,
          $$InstitutionsCacheTableFilterComposer,
          $$InstitutionsCacheTableOrderingComposer,
          $$InstitutionsCacheTableAnnotationComposer,
          $$InstitutionsCacheTableCreateCompanionBuilder,
          $$InstitutionsCacheTableUpdateCompanionBuilder,
          (
            InstitutionsCacheData,
            BaseReferences<
              _$AppDatabase,
              $InstitutionsCacheTable,
              InstitutionsCacheData
            >,
          ),
          InstitutionsCacheData,
          PrefetchHooks Function()
        > {
  $$InstitutionsCacheTableTableManager(
    _$AppDatabase db,
    $InstitutionsCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstitutionsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstitutionsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstitutionsCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> offlineWindowHours = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstitutionsCacheCompanion(
                id: id,
                code: code,
                name: name,
                offlineWindowHours: offlineWindowHours,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                required int offlineWindowHours,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => InstitutionsCacheCompanion.insert(
                id: id,
                code: code,
                name: name,
                offlineWindowHours: offlineWindowHours,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstitutionsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstitutionsCacheTable,
      InstitutionsCacheData,
      $$InstitutionsCacheTableFilterComposer,
      $$InstitutionsCacheTableOrderingComposer,
      $$InstitutionsCacheTableAnnotationComposer,
      $$InstitutionsCacheTableCreateCompanionBuilder,
      $$InstitutionsCacheTableUpdateCompanionBuilder,
      (
        InstitutionsCacheData,
        BaseReferences<
          _$AppDatabase,
          $InstitutionsCacheTable,
          InstitutionsCacheData
        >,
      ),
      InstitutionsCacheData,
      PrefetchHooks Function()
    >;
typedef $$UsersCacheTableCreateCompanionBuilder = UsersCacheCompanion Function({
  required String id,
  required String email,
  required String fullName,
  required String institutionId,
  required String roles,
  required String status,
  Value<int> rowid,
});
typedef $$UsersCacheTableUpdateCompanionBuilder = UsersCacheCompanion Function({
  Value<String> id,
  Value<String> email,
  Value<String> fullName,
  Value<String> institutionId,
  Value<String> roles,
  Value<String> status,
  Value<int> rowid,
});

class $$UsersCacheTableFilterComposer
    extends Composer<_$AppDatabase, $UsersCacheTable> {
  $$UsersCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roles => $composableBuilder(
    column: $table.roles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersCacheTable> {
  $$UsersCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roles => $composableBuilder(
    column: $table.roles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersCacheTable> {
  $$UsersCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roles =>
      $composableBuilder(column: $table.roles, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$UsersCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersCacheTable,
          UsersCacheData,
          $$UsersCacheTableFilterComposer,
          $$UsersCacheTableOrderingComposer,
          $$UsersCacheTableAnnotationComposer,
          $$UsersCacheTableCreateCompanionBuilder,
          $$UsersCacheTableUpdateCompanionBuilder,
          (
            UsersCacheData,
            BaseReferences<_$AppDatabase, $UsersCacheTable, UsersCacheData>,
          ),
          UsersCacheData,
          PrefetchHooks Function()
        > {
  $$UsersCacheTableTableManager(_$AppDatabase db, $UsersCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> institutionId = const Value.absent(),
                Value<String> roles = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCacheCompanion(
                id: id,
                email: email,
                fullName: fullName,
                institutionId: institutionId,
                roles: roles,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String fullName,
                required String institutionId,
                required String roles,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => UsersCacheCompanion.insert(
                id: id,
                email: email,
                fullName: fullName,
                institutionId: institutionId,
                roles: roles,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersCacheTable,
      UsersCacheData,
      $$UsersCacheTableFilterComposer,
      $$UsersCacheTableOrderingComposer,
      $$UsersCacheTableAnnotationComposer,
      $$UsersCacheTableCreateCompanionBuilder,
      $$UsersCacheTableUpdateCompanionBuilder,
      (
        UsersCacheData,
        BaseReferences<_$AppDatabase, $UsersCacheTable, UsersCacheData>,
      ),
      UsersCacheData,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CurrentUserTableTableManager get currentUser =>
      $$CurrentUserTableTableManager(_db, _db.currentUser);
  $$InstitutionsCacheTableTableManager get institutionsCache =>
      $$InstitutionsCacheTableTableManager(_db, _db.institutionsCache);
  $$UsersCacheTableTableManager get usersCache =>
      $$UsersCacheTableTableManager(_db, _db.usersCache);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
