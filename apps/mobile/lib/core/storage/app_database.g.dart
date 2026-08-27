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
  static const VerificationMeta _documentTypeMeta = const VerificationMeta(
    'documentType',
  );
  @override
  late final GeneratedColumn<String> documentType = GeneratedColumn<String>(
    'document_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentNumberMeta = const VerificationMeta(
    'documentNumber',
  );
  @override
  late final GeneratedColumn<String> documentNumber = GeneratedColumn<String>(
    'document_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _professionCodeMeta = const VerificationMeta(
    'professionCode',
  );
  @override
  late final GeneratedColumn<String> professionCode = GeneratedColumn<String>(
    'profession_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _professionalRegistrationNumberMeta =
      const VerificationMeta('professionalRegistrationNumber');
  @override
  late final GeneratedColumn<String> professionalRegistrationNumber =
      GeneratedColumn<String>(
        'professional_registration_number',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _professionalRegistrationTypeMeta =
      const VerificationMeta('professionalRegistrationType');
  @override
  late final GeneratedColumn<String> professionalRegistrationType =
      GeneratedColumn<String>(
        'professional_registration_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    fullName,
    institutionId,
    roles,
    status,
    documentType,
    documentNumber,
    phone,
    birthDate,
    gender,
    professionCode,
    professionalRegistrationNumber,
    professionalRegistrationType,
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
    if (data.containsKey('document_type')) {
      context.handle(
        _documentTypeMeta,
        documentType.isAcceptableOrUnknown(
          data['document_type']!,
          _documentTypeMeta,
        ),
      );
    }
    if (data.containsKey('document_number')) {
      context.handle(
        _documentNumberMeta,
        documentNumber.isAcceptableOrUnknown(
          data['document_number']!,
          _documentNumberMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('profession_code')) {
      context.handle(
        _professionCodeMeta,
        professionCode.isAcceptableOrUnknown(
          data['profession_code']!,
          _professionCodeMeta,
        ),
      );
    }
    if (data.containsKey('professional_registration_number')) {
      context.handle(
        _professionalRegistrationNumberMeta,
        professionalRegistrationNumber.isAcceptableOrUnknown(
          data['professional_registration_number']!,
          _professionalRegistrationNumberMeta,
        ),
      );
    }
    if (data.containsKey('professional_registration_type')) {
      context.handle(
        _professionalRegistrationTypeMeta,
        professionalRegistrationType.isAcceptableOrUnknown(
          data['professional_registration_type']!,
          _professionalRegistrationTypeMeta,
        ),
      );
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
      documentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_type'],
      ),
      documentNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_number'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date'],
      ),
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      professionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profession_code'],
      ),
      professionalRegistrationNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}professional_registration_number'],
      ),
      professionalRegistrationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}professional_registration_type'],
      ),
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

  /// Perfil ampliado del personal de salud (nullable por compatibilidad con
  /// usuarios creados antes de la migracion V4).
  final String? documentType;
  final String? documentNumber;
  final String? phone;

  /// Fecha de nacimiento en formato ISO (yyyy-MM-dd).
  final String? birthDate;
  final String? gender;
  final String? professionCode;
  final String? professionalRegistrationNumber;
  final String? professionalRegistrationType;
  const UsersCacheData({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institutionId,
    required this.roles,
    required this.status,
    this.documentType,
    this.documentNumber,
    this.phone,
    this.birthDate,
    this.gender,
    this.professionCode,
    this.professionalRegistrationNumber,
    this.professionalRegistrationType,
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
    if (!nullToAbsent || documentType != null) {
      map['document_type'] = Variable<String>(documentType);
    }
    if (!nullToAbsent || documentNumber != null) {
      map['document_number'] = Variable<String>(documentNumber);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<String>(birthDate);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || professionCode != null) {
      map['profession_code'] = Variable<String>(professionCode);
    }
    if (!nullToAbsent || professionalRegistrationNumber != null) {
      map['professional_registration_number'] = Variable<String>(
        professionalRegistrationNumber,
      );
    }
    if (!nullToAbsent || professionalRegistrationType != null) {
      map['professional_registration_type'] = Variable<String>(
        professionalRegistrationType,
      );
    }
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
      documentType: documentType == null && nullToAbsent
          ? const Value.absent()
          : Value(documentType),
      documentNumber: documentNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(documentNumber),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      professionCode: professionCode == null && nullToAbsent
          ? const Value.absent()
          : Value(professionCode),
      professionalRegistrationNumber:
          professionalRegistrationNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(professionalRegistrationNumber),
      professionalRegistrationType:
          professionalRegistrationType == null && nullToAbsent
          ? const Value.absent()
          : Value(professionalRegistrationType),
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
      documentType: serializer.fromJson<String?>(json['documentType']),
      documentNumber: serializer.fromJson<String?>(json['documentNumber']),
      phone: serializer.fromJson<String?>(json['phone']),
      birthDate: serializer.fromJson<String?>(json['birthDate']),
      gender: serializer.fromJson<String?>(json['gender']),
      professionCode: serializer.fromJson<String?>(json['professionCode']),
      professionalRegistrationNumber: serializer.fromJson<String?>(
        json['professionalRegistrationNumber'],
      ),
      professionalRegistrationType: serializer.fromJson<String?>(
        json['professionalRegistrationType'],
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
      'status': serializer.toJson<String>(status),
      'documentType': serializer.toJson<String?>(documentType),
      'documentNumber': serializer.toJson<String?>(documentNumber),
      'phone': serializer.toJson<String?>(phone),
      'birthDate': serializer.toJson<String?>(birthDate),
      'gender': serializer.toJson<String?>(gender),
      'professionCode': serializer.toJson<String?>(professionCode),
      'professionalRegistrationNumber': serializer.toJson<String?>(
        professionalRegistrationNumber,
      ),
      'professionalRegistrationType': serializer.toJson<String?>(
        professionalRegistrationType,
      ),
    };
  }

  UsersCacheData copyWith({
    String? id,
    String? email,
    String? fullName,
    String? institutionId,
    String? roles,
    String? status,
    Value<String?> documentType = const Value.absent(),
    Value<String?> documentNumber = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> birthDate = const Value.absent(),
    Value<String?> gender = const Value.absent(),
    Value<String?> professionCode = const Value.absent(),
    Value<String?> professionalRegistrationNumber = const Value.absent(),
    Value<String?> professionalRegistrationType = const Value.absent(),
  }) => UsersCacheData(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    institutionId: institutionId ?? this.institutionId,
    roles: roles ?? this.roles,
    status: status ?? this.status,
    documentType: documentType.present ? documentType.value : this.documentType,
    documentNumber: documentNumber.present
        ? documentNumber.value
        : this.documentNumber,
    phone: phone.present ? phone.value : this.phone,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    gender: gender.present ? gender.value : this.gender,
    professionCode: professionCode.present
        ? professionCode.value
        : this.professionCode,
    professionalRegistrationNumber: professionalRegistrationNumber.present
        ? professionalRegistrationNumber.value
        : this.professionalRegistrationNumber,
    professionalRegistrationType: professionalRegistrationType.present
        ? professionalRegistrationType.value
        : this.professionalRegistrationType,
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
      documentType: data.documentType.present
          ? data.documentType.value
          : this.documentType,
      documentNumber: data.documentNumber.present
          ? data.documentNumber.value
          : this.documentNumber,
      phone: data.phone.present ? data.phone.value : this.phone,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      gender: data.gender.present ? data.gender.value : this.gender,
      professionCode: data.professionCode.present
          ? data.professionCode.value
          : this.professionCode,
      professionalRegistrationNumber:
          data.professionalRegistrationNumber.present
          ? data.professionalRegistrationNumber.value
          : this.professionalRegistrationNumber,
      professionalRegistrationType: data.professionalRegistrationType.present
          ? data.professionalRegistrationType.value
          : this.professionalRegistrationType,
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
          ..write('status: $status, ')
          ..write('documentType: $documentType, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('phone: $phone, ')
          ..write('birthDate: $birthDate, ')
          ..write('gender: $gender, ')
          ..write('professionCode: $professionCode, ')
          ..write(
            'professionalRegistrationNumber: $professionalRegistrationNumber, ',
          )
          ..write('professionalRegistrationType: $professionalRegistrationType')
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
    status,
    documentType,
    documentNumber,
    phone,
    birthDate,
    gender,
    professionCode,
    professionalRegistrationNumber,
    professionalRegistrationType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsersCacheData &&
          other.id == this.id &&
          other.email == this.email &&
          other.fullName == this.fullName &&
          other.institutionId == this.institutionId &&
          other.roles == this.roles &&
          other.status == this.status &&
          other.documentType == this.documentType &&
          other.documentNumber == this.documentNumber &&
          other.phone == this.phone &&
          other.birthDate == this.birthDate &&
          other.gender == this.gender &&
          other.professionCode == this.professionCode &&
          other.professionalRegistrationNumber ==
              this.professionalRegistrationNumber &&
          other.professionalRegistrationType ==
              this.professionalRegistrationType);
}

class UsersCacheCompanion extends UpdateCompanion<UsersCacheData> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> fullName;
  final Value<String> institutionId;
  final Value<String> roles;
  final Value<String> status;
  final Value<String?> documentType;
  final Value<String?> documentNumber;
  final Value<String?> phone;
  final Value<String?> birthDate;
  final Value<String?> gender;
  final Value<String?> professionCode;
  final Value<String?> professionalRegistrationNumber;
  final Value<String?> professionalRegistrationType;
  final Value<int> rowid;
  const UsersCacheCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.fullName = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.roles = const Value.absent(),
    this.status = const Value.absent(),
    this.documentType = const Value.absent(),
    this.documentNumber = const Value.absent(),
    this.phone = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.gender = const Value.absent(),
    this.professionCode = const Value.absent(),
    this.professionalRegistrationNumber = const Value.absent(),
    this.professionalRegistrationType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCacheCompanion.insert({
    required String id,
    required String email,
    required String fullName,
    required String institutionId,
    required String roles,
    required String status,
    this.documentType = const Value.absent(),
    this.documentNumber = const Value.absent(),
    this.phone = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.gender = const Value.absent(),
    this.professionCode = const Value.absent(),
    this.professionalRegistrationNumber = const Value.absent(),
    this.professionalRegistrationType = const Value.absent(),
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
    Expression<String>? documentType,
    Expression<String>? documentNumber,
    Expression<String>? phone,
    Expression<String>? birthDate,
    Expression<String>? gender,
    Expression<String>? professionCode,
    Expression<String>? professionalRegistrationNumber,
    Expression<String>? professionalRegistrationType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (fullName != null) 'full_name': fullName,
      if (institutionId != null) 'institution_id': institutionId,
      if (roles != null) 'roles': roles,
      if (status != null) 'status': status,
      if (documentType != null) 'document_type': documentType,
      if (documentNumber != null) 'document_number': documentNumber,
      if (phone != null) 'phone': phone,
      if (birthDate != null) 'birth_date': birthDate,
      if (gender != null) 'gender': gender,
      if (professionCode != null) 'profession_code': professionCode,
      if (professionalRegistrationNumber != null)
        'professional_registration_number': professionalRegistrationNumber,
      if (professionalRegistrationType != null)
        'professional_registration_type': professionalRegistrationType,
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
    Value<String?>? documentType,
    Value<String?>? documentNumber,
    Value<String?>? phone,
    Value<String?>? birthDate,
    Value<String?>? gender,
    Value<String?>? professionCode,
    Value<String?>? professionalRegistrationNumber,
    Value<String?>? professionalRegistrationType,
    Value<int>? rowid,
  }) {
    return UsersCacheCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      institutionId: institutionId ?? this.institutionId,
      roles: roles ?? this.roles,
      status: status ?? this.status,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      professionCode: professionCode ?? this.professionCode,
      professionalRegistrationNumber:
          professionalRegistrationNumber ?? this.professionalRegistrationNumber,
      professionalRegistrationType:
          professionalRegistrationType ?? this.professionalRegistrationType,
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
    if (documentType.present) {
      map['document_type'] = Variable<String>(documentType.value);
    }
    if (documentNumber.present) {
      map['document_number'] = Variable<String>(documentNumber.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (professionCode.present) {
      map['profession_code'] = Variable<String>(professionCode.value);
    }
    if (professionalRegistrationNumber.present) {
      map['professional_registration_number'] = Variable<String>(
        professionalRegistrationNumber.value,
      );
    }
    if (professionalRegistrationType.present) {
      map['professional_registration_type'] = Variable<String>(
        professionalRegistrationType.value,
      );
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
          ..write('documentType: $documentType, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('phone: $phone, ')
          ..write('birthDate: $birthDate, ')
          ..write('gender: $gender, ')
          ..write('professionCode: $professionCode, ')
          ..write(
            'professionalRegistrationNumber: $professionalRegistrationNumber, ',
          )
          ..write(
            'professionalRegistrationType: $professionalRegistrationType, ',
          )
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

class $VaccinesCacheTable extends VaccinesCache
    with TableInfo<$VaccinesCacheTable, VaccinesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaccinesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxDosesMeta = const VerificationMeta(
    'maxDoses',
  );
  @override
  late final GeneratedColumn<int> maxDoses = GeneratedColumn<int>(
    'max_doses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minAgeMonthsMeta = const VerificationMeta(
    'minAgeMonths',
  );
  @override
  late final GeneratedColumn<int> minAgeMonths = GeneratedColumn<int>(
    'min_age_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxAgeMonthsMeta = const VerificationMeta(
    'maxAgeMonths',
  );
  @override
  late final GeneratedColumn<int> maxAgeMonths = GeneratedColumn<int>(
    'max_age_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    code,
    category,
    maxDoses,
    minAgeMonths,
    maxAgeMonths,
    active,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vaccines_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaccinesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('max_doses')) {
      context.handle(
        _maxDosesMeta,
        maxDoses.isAcceptableOrUnknown(data['max_doses']!, _maxDosesMeta),
      );
    } else if (isInserting) {
      context.missing(_maxDosesMeta);
    }
    if (data.containsKey('min_age_months')) {
      context.handle(
        _minAgeMonthsMeta,
        minAgeMonths.isAcceptableOrUnknown(
          data['min_age_months']!,
          _minAgeMonthsMeta,
        ),
      );
    }
    if (data.containsKey('max_age_months')) {
      context.handle(
        _maxAgeMonthsMeta,
        maxAgeMonths.isAcceptableOrUnknown(
          data['max_age_months']!,
          _maxAgeMonthsMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaccinesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaccinesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      maxDoses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_doses'],
      )!,
      minAgeMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_age_months'],
      ),
      maxAgeMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_age_months'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $VaccinesCacheTable createAlias(String alias) {
    return $VaccinesCacheTable(attachedDatabase, alias);
  }
}

class VaccinesCacheData extends DataClass
    implements Insertable<VaccinesCacheData> {
  final String id;
  final String name;
  final String code;
  final String category;
  final int maxDoses;
  final int? minAgeMonths;
  final int? maxAgeMonths;
  final bool active;
  final int version;
  const VaccinesCacheData({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.maxDoses,
    this.minAgeMonths,
    this.maxAgeMonths,
    required this.active,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['category'] = Variable<String>(category);
    map['max_doses'] = Variable<int>(maxDoses);
    if (!nullToAbsent || minAgeMonths != null) {
      map['min_age_months'] = Variable<int>(minAgeMonths);
    }
    if (!nullToAbsent || maxAgeMonths != null) {
      map['max_age_months'] = Variable<int>(maxAgeMonths);
    }
    map['active'] = Variable<bool>(active);
    map['version'] = Variable<int>(version);
    return map;
  }

  VaccinesCacheCompanion toCompanion(bool nullToAbsent) {
    return VaccinesCacheCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      category: Value(category),
      maxDoses: Value(maxDoses),
      minAgeMonths: minAgeMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(minAgeMonths),
      maxAgeMonths: maxAgeMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(maxAgeMonths),
      active: Value(active),
      version: Value(version),
    );
  }

  factory VaccinesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaccinesCacheData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      category: serializer.fromJson<String>(json['category']),
      maxDoses: serializer.fromJson<int>(json['maxDoses']),
      minAgeMonths: serializer.fromJson<int?>(json['minAgeMonths']),
      maxAgeMonths: serializer.fromJson<int?>(json['maxAgeMonths']),
      active: serializer.fromJson<bool>(json['active']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'category': serializer.toJson<String>(category),
      'maxDoses': serializer.toJson<int>(maxDoses),
      'minAgeMonths': serializer.toJson<int?>(minAgeMonths),
      'maxAgeMonths': serializer.toJson<int?>(maxAgeMonths),
      'active': serializer.toJson<bool>(active),
      'version': serializer.toJson<int>(version),
    };
  }

  VaccinesCacheData copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    int? maxDoses,
    Value<int?> minAgeMonths = const Value.absent(),
    Value<int?> maxAgeMonths = const Value.absent(),
    bool? active,
    int? version,
  }) => VaccinesCacheData(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    category: category ?? this.category,
    maxDoses: maxDoses ?? this.maxDoses,
    minAgeMonths: minAgeMonths.present ? minAgeMonths.value : this.minAgeMonths,
    maxAgeMonths: maxAgeMonths.present ? maxAgeMonths.value : this.maxAgeMonths,
    active: active ?? this.active,
    version: version ?? this.version,
  );
  VaccinesCacheData copyWithCompanion(VaccinesCacheCompanion data) {
    return VaccinesCacheData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      category: data.category.present ? data.category.value : this.category,
      maxDoses: data.maxDoses.present ? data.maxDoses.value : this.maxDoses,
      minAgeMonths: data.minAgeMonths.present
          ? data.minAgeMonths.value
          : this.minAgeMonths,
      maxAgeMonths: data.maxAgeMonths.present
          ? data.maxAgeMonths.value
          : this.maxAgeMonths,
      active: data.active.present ? data.active.value : this.active,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaccinesCacheData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('category: $category, ')
          ..write('maxDoses: $maxDoses, ')
          ..write('minAgeMonths: $minAgeMonths, ')
          ..write('maxAgeMonths: $maxAgeMonths, ')
          ..write('active: $active, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    code,
    category,
    maxDoses,
    minAgeMonths,
    maxAgeMonths,
    active,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaccinesCacheData &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.category == this.category &&
          other.maxDoses == this.maxDoses &&
          other.minAgeMonths == this.minAgeMonths &&
          other.maxAgeMonths == this.maxAgeMonths &&
          other.active == this.active &&
          other.version == this.version);
}

class VaccinesCacheCompanion extends UpdateCompanion<VaccinesCacheData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> code;
  final Value<String> category;
  final Value<int> maxDoses;
  final Value<int?> minAgeMonths;
  final Value<int?> maxAgeMonths;
  final Value<bool> active;
  final Value<int> version;
  final Value<int> rowid;
  const VaccinesCacheCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.category = const Value.absent(),
    this.maxDoses = const Value.absent(),
    this.minAgeMonths = const Value.absent(),
    this.maxAgeMonths = const Value.absent(),
    this.active = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaccinesCacheCompanion.insert({
    required String id,
    required String name,
    required String code,
    required String category,
    required int maxDoses,
    this.minAgeMonths = const Value.absent(),
    this.maxAgeMonths = const Value.absent(),
    required bool active,
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       code = Value(code),
       category = Value(category),
       maxDoses = Value(maxDoses),
       active = Value(active),
       version = Value(version);
  static Insertable<VaccinesCacheData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? category,
    Expression<int>? maxDoses,
    Expression<int>? minAgeMonths,
    Expression<int>? maxAgeMonths,
    Expression<bool>? active,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (category != null) 'category': category,
      if (maxDoses != null) 'max_doses': maxDoses,
      if (minAgeMonths != null) 'min_age_months': minAgeMonths,
      if (maxAgeMonths != null) 'max_age_months': maxAgeMonths,
      if (active != null) 'active': active,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaccinesCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? code,
    Value<String>? category,
    Value<int>? maxDoses,
    Value<int?>? minAgeMonths,
    Value<int?>? maxAgeMonths,
    Value<bool>? active,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return VaccinesCacheCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      maxDoses: maxDoses ?? this.maxDoses,
      minAgeMonths: minAgeMonths ?? this.minAgeMonths,
      maxAgeMonths: maxAgeMonths ?? this.maxAgeMonths,
      active: active ?? this.active,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (maxDoses.present) {
      map['max_doses'] = Variable<int>(maxDoses.value);
    }
    if (minAgeMonths.present) {
      map['min_age_months'] = Variable<int>(minAgeMonths.value);
    }
    if (maxAgeMonths.present) {
      map['max_age_months'] = Variable<int>(maxAgeMonths.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaccinesCacheCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('category: $category, ')
          ..write('maxDoses: $maxDoses, ')
          ..write('minAgeMonths: $minAgeMonths, ')
          ..write('maxAgeMonths: $maxAgeMonths, ')
          ..write('active: $active, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaccineOptionsCacheTable extends VaccineOptionsCache
    with TableInfo<$VaccineOptionsCacheTable, VaccineOptionsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaccineOptionsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vaccineIdMeta = const VerificationMeta(
    'vaccineId',
  );
  @override
  late final GeneratedColumn<String> vaccineId = GeneratedColumn<String>(
    'vaccine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldTypeMeta = const VerificationMeta(
    'fieldType',
  );
  @override
  late final GeneratedColumn<String> fieldType = GeneratedColumn<String>(
    'field_type',
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sourceTemplateIdMeta = const VerificationMeta(
    'sourceTemplateId',
  );
  @override
  late final GeneratedColumn<String> sourceTemplateId = GeneratedColumn<String>(
    'source_template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vaccineId,
    fieldType,
    value,
    displayName,
    sortOrder,
    isDefault,
    isActive,
    sourceTemplateId,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vaccine_options_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaccineOptionsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vaccine_id')) {
      context.handle(
        _vaccineIdMeta,
        vaccineId.isAcceptableOrUnknown(data['vaccine_id']!, _vaccineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaccineIdMeta);
    }
    if (data.containsKey('field_type')) {
      context.handle(
        _fieldTypeMeta,
        fieldType.isAcceptableOrUnknown(data['field_type']!, _fieldTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldTypeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    } else if (isInserting) {
      context.missing(_isDefaultMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('source_template_id')) {
      context.handle(
        _sourceTemplateIdMeta,
        sourceTemplateId.isAcceptableOrUnknown(
          data['source_template_id']!,
          _sourceTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaccineOptionsCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaccineOptionsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vaccineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vaccine_id'],
      )!,
      fieldType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      sourceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_template_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $VaccineOptionsCacheTable createAlias(String alias) {
    return $VaccineOptionsCacheTable(attachedDatabase, alias);
  }
}

class VaccineOptionsCacheData extends DataClass
    implements Insertable<VaccineOptionsCacheData> {
  final String id;
  final String vaccineId;
  final String fieldType;
  final String value;
  final String displayName;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final String? sourceTemplateId;
  final int version;
  const VaccineOptionsCacheData({
    required this.id,
    required this.vaccineId,
    required this.fieldType,
    required this.value,
    required this.displayName,
    required this.sortOrder,
    required this.isDefault,
    required this.isActive,
    this.sourceTemplateId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vaccine_id'] = Variable<String>(vaccineId);
    map['field_type'] = Variable<String>(fieldType);
    map['value'] = Variable<String>(value);
    map['display_name'] = Variable<String>(displayName);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || sourceTemplateId != null) {
      map['source_template_id'] = Variable<String>(sourceTemplateId);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  VaccineOptionsCacheCompanion toCompanion(bool nullToAbsent) {
    return VaccineOptionsCacheCompanion(
      id: Value(id),
      vaccineId: Value(vaccineId),
      fieldType: Value(fieldType),
      value: Value(value),
      displayName: Value(displayName),
      sortOrder: Value(sortOrder),
      isDefault: Value(isDefault),
      isActive: Value(isActive),
      sourceTemplateId: sourceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTemplateId),
      version: Value(version),
    );
  }

  factory VaccineOptionsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaccineOptionsCacheData(
      id: serializer.fromJson<String>(json['id']),
      vaccineId: serializer.fromJson<String>(json['vaccineId']),
      fieldType: serializer.fromJson<String>(json['fieldType']),
      value: serializer.fromJson<String>(json['value']),
      displayName: serializer.fromJson<String>(json['displayName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      sourceTemplateId: serializer.fromJson<String?>(json['sourceTemplateId']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vaccineId': serializer.toJson<String>(vaccineId),
      'fieldType': serializer.toJson<String>(fieldType),
      'value': serializer.toJson<String>(value),
      'displayName': serializer.toJson<String>(displayName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isActive': serializer.toJson<bool>(isActive),
      'sourceTemplateId': serializer.toJson<String?>(sourceTemplateId),
      'version': serializer.toJson<int>(version),
    };
  }

  VaccineOptionsCacheData copyWith({
    String? id,
    String? vaccineId,
    String? fieldType,
    String? value,
    String? displayName,
    int? sortOrder,
    bool? isDefault,
    bool? isActive,
    Value<String?> sourceTemplateId = const Value.absent(),
    int? version,
  }) => VaccineOptionsCacheData(
    id: id ?? this.id,
    vaccineId: vaccineId ?? this.vaccineId,
    fieldType: fieldType ?? this.fieldType,
    value: value ?? this.value,
    displayName: displayName ?? this.displayName,
    sortOrder: sortOrder ?? this.sortOrder,
    isDefault: isDefault ?? this.isDefault,
    isActive: isActive ?? this.isActive,
    sourceTemplateId: sourceTemplateId.present
        ? sourceTemplateId.value
        : this.sourceTemplateId,
    version: version ?? this.version,
  );
  VaccineOptionsCacheData copyWithCompanion(VaccineOptionsCacheCompanion data) {
    return VaccineOptionsCacheData(
      id: data.id.present ? data.id.value : this.id,
      vaccineId: data.vaccineId.present ? data.vaccineId.value : this.vaccineId,
      fieldType: data.fieldType.present ? data.fieldType.value : this.fieldType,
      value: data.value.present ? data.value.value : this.value,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      sourceTemplateId: data.sourceTemplateId.present
          ? data.sourceTemplateId.value
          : this.sourceTemplateId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaccineOptionsCacheData(')
          ..write('id: $id, ')
          ..write('vaccineId: $vaccineId, ')
          ..write('fieldType: $fieldType, ')
          ..write('value: $value, ')
          ..write('displayName: $displayName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('isActive: $isActive, ')
          ..write('sourceTemplateId: $sourceTemplateId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vaccineId,
    fieldType,
    value,
    displayName,
    sortOrder,
    isDefault,
    isActive,
    sourceTemplateId,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaccineOptionsCacheData &&
          other.id == this.id &&
          other.vaccineId == this.vaccineId &&
          other.fieldType == this.fieldType &&
          other.value == this.value &&
          other.displayName == this.displayName &&
          other.sortOrder == this.sortOrder &&
          other.isDefault == this.isDefault &&
          other.isActive == this.isActive &&
          other.sourceTemplateId == this.sourceTemplateId &&
          other.version == this.version);
}

class VaccineOptionsCacheCompanion
    extends UpdateCompanion<VaccineOptionsCacheData> {
  final Value<String> id;
  final Value<String> vaccineId;
  final Value<String> fieldType;
  final Value<String> value;
  final Value<String> displayName;
  final Value<int> sortOrder;
  final Value<bool> isDefault;
  final Value<bool> isActive;
  final Value<String?> sourceTemplateId;
  final Value<int> version;
  final Value<int> rowid;
  const VaccineOptionsCacheCompanion({
    this.id = const Value.absent(),
    this.vaccineId = const Value.absent(),
    this.fieldType = const Value.absent(),
    this.value = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sourceTemplateId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaccineOptionsCacheCompanion.insert({
    required String id,
    required String vaccineId,
    required String fieldType,
    required String value,
    required String displayName,
    required int sortOrder,
    required bool isDefault,
    required bool isActive,
    this.sourceTemplateId = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vaccineId = Value(vaccineId),
       fieldType = Value(fieldType),
       value = Value(value),
       displayName = Value(displayName),
       sortOrder = Value(sortOrder),
       isDefault = Value(isDefault),
       isActive = Value(isActive),
       version = Value(version);
  static Insertable<VaccineOptionsCacheData> custom({
    Expression<String>? id,
    Expression<String>? vaccineId,
    Expression<String>? fieldType,
    Expression<String>? value,
    Expression<String>? displayName,
    Expression<int>? sortOrder,
    Expression<bool>? isDefault,
    Expression<bool>? isActive,
    Expression<String>? sourceTemplateId,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vaccineId != null) 'vaccine_id': vaccineId,
      if (fieldType != null) 'field_type': fieldType,
      if (value != null) 'value': value,
      if (displayName != null) 'display_name': displayName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDefault != null) 'is_default': isDefault,
      if (isActive != null) 'is_active': isActive,
      if (sourceTemplateId != null) 'source_template_id': sourceTemplateId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaccineOptionsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? vaccineId,
    Value<String>? fieldType,
    Value<String>? value,
    Value<String>? displayName,
    Value<int>? sortOrder,
    Value<bool>? isDefault,
    Value<bool>? isActive,
    Value<String?>? sourceTemplateId,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return VaccineOptionsCacheCompanion(
      id: id ?? this.id,
      vaccineId: vaccineId ?? this.vaccineId,
      fieldType: fieldType ?? this.fieldType,
      value: value ?? this.value,
      displayName: displayName ?? this.displayName,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vaccineId.present) {
      map['vaccine_id'] = Variable<String>(vaccineId.value);
    }
    if (fieldType.present) {
      map['field_type'] = Variable<String>(fieldType.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (sourceTemplateId.present) {
      map['source_template_id'] = Variable<String>(sourceTemplateId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaccineOptionsCacheCompanion(')
          ..write('id: $id, ')
          ..write('vaccineId: $vaccineId, ')
          ..write('fieldType: $fieldType, ')
          ..write('value: $value, ')
          ..write('displayName: $displayName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('isActive: $isActive, ')
          ..write('sourceTemplateId: $sourceTemplateId, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstitutionVaccinesCacheTable extends InstitutionVaccinesCache
    with
        TableInfo<
          $InstitutionVaccinesCacheTable,
          InstitutionVaccinesCacheData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstitutionVaccinesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _vaccineIdMeta = const VerificationMeta(
    'vaccineId',
  );
  @override
  late final GeneratedColumn<String> vaccineId = GeneratedColumn<String>(
    'vaccine_id',
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
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    institutionId,
    vaccineId,
    name,
    code,
    category,
    enabled,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'institution_vaccines_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstitutionVaccinesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('vaccine_id')) {
      context.handle(
        _vaccineIdMeta,
        vaccineId.isAcceptableOrUnknown(data['vaccine_id']!, _vaccineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaccineIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstitutionVaccinesCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstitutionVaccinesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      institutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_id'],
      )!,
      vaccineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vaccine_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $InstitutionVaccinesCacheTable createAlias(String alias) {
    return $InstitutionVaccinesCacheTable(attachedDatabase, alias);
  }
}

class InstitutionVaccinesCacheData extends DataClass
    implements Insertable<InstitutionVaccinesCacheData> {
  final String id;
  final String institutionId;
  final String vaccineId;
  final String name;
  final String code;
  final String category;
  final bool enabled;
  final int version;
  const InstitutionVaccinesCacheData({
    required this.id,
    required this.institutionId,
    required this.vaccineId,
    required this.name,
    required this.code,
    required this.category,
    required this.enabled,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['institution_id'] = Variable<String>(institutionId);
    map['vaccine_id'] = Variable<String>(vaccineId);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['category'] = Variable<String>(category);
    map['enabled'] = Variable<bool>(enabled);
    map['version'] = Variable<int>(version);
    return map;
  }

  InstitutionVaccinesCacheCompanion toCompanion(bool nullToAbsent) {
    return InstitutionVaccinesCacheCompanion(
      id: Value(id),
      institutionId: Value(institutionId),
      vaccineId: Value(vaccineId),
      name: Value(name),
      code: Value(code),
      category: Value(category),
      enabled: Value(enabled),
      version: Value(version),
    );
  }

  factory InstitutionVaccinesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstitutionVaccinesCacheData(
      id: serializer.fromJson<String>(json['id']),
      institutionId: serializer.fromJson<String>(json['institutionId']),
      vaccineId: serializer.fromJson<String>(json['vaccineId']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      category: serializer.fromJson<String>(json['category']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'institutionId': serializer.toJson<String>(institutionId),
      'vaccineId': serializer.toJson<String>(vaccineId),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'category': serializer.toJson<String>(category),
      'enabled': serializer.toJson<bool>(enabled),
      'version': serializer.toJson<int>(version),
    };
  }

  InstitutionVaccinesCacheData copyWith({
    String? id,
    String? institutionId,
    String? vaccineId,
    String? name,
    String? code,
    String? category,
    bool? enabled,
    int? version,
  }) => InstitutionVaccinesCacheData(
    id: id ?? this.id,
    institutionId: institutionId ?? this.institutionId,
    vaccineId: vaccineId ?? this.vaccineId,
    name: name ?? this.name,
    code: code ?? this.code,
    category: category ?? this.category,
    enabled: enabled ?? this.enabled,
    version: version ?? this.version,
  );
  InstitutionVaccinesCacheData copyWithCompanion(
    InstitutionVaccinesCacheCompanion data,
  ) {
    return InstitutionVaccinesCacheData(
      id: data.id.present ? data.id.value : this.id,
      institutionId: data.institutionId.present
          ? data.institutionId.value
          : this.institutionId,
      vaccineId: data.vaccineId.present ? data.vaccineId.value : this.vaccineId,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      category: data.category.present ? data.category.value : this.category,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstitutionVaccinesCacheData(')
          ..write('id: $id, ')
          ..write('institutionId: $institutionId, ')
          ..write('vaccineId: $vaccineId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('category: $category, ')
          ..write('enabled: $enabled, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    institutionId,
    vaccineId,
    name,
    code,
    category,
    enabled,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstitutionVaccinesCacheData &&
          other.id == this.id &&
          other.institutionId == this.institutionId &&
          other.vaccineId == this.vaccineId &&
          other.name == this.name &&
          other.code == this.code &&
          other.category == this.category &&
          other.enabled == this.enabled &&
          other.version == this.version);
}

class InstitutionVaccinesCacheCompanion
    extends UpdateCompanion<InstitutionVaccinesCacheData> {
  final Value<String> id;
  final Value<String> institutionId;
  final Value<String> vaccineId;
  final Value<String> name;
  final Value<String> code;
  final Value<String> category;
  final Value<bool> enabled;
  final Value<int> version;
  final Value<int> rowid;
  const InstitutionVaccinesCacheCompanion({
    this.id = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.vaccineId = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.category = const Value.absent(),
    this.enabled = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstitutionVaccinesCacheCompanion.insert({
    required String id,
    required String institutionId,
    required String vaccineId,
    required String name,
    required String code,
    required String category,
    required bool enabled,
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       institutionId = Value(institutionId),
       vaccineId = Value(vaccineId),
       name = Value(name),
       code = Value(code),
       category = Value(category),
       enabled = Value(enabled),
       version = Value(version);
  static Insertable<InstitutionVaccinesCacheData> custom({
    Expression<String>? id,
    Expression<String>? institutionId,
    Expression<String>? vaccineId,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? category,
    Expression<bool>? enabled,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (institutionId != null) 'institution_id': institutionId,
      if (vaccineId != null) 'vaccine_id': vaccineId,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (category != null) 'category': category,
      if (enabled != null) 'enabled': enabled,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstitutionVaccinesCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? institutionId,
    Value<String>? vaccineId,
    Value<String>? name,
    Value<String>? code,
    Value<String>? category,
    Value<bool>? enabled,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return InstitutionVaccinesCacheCompanion(
      id: id ?? this.id,
      institutionId: institutionId ?? this.institutionId,
      vaccineId: vaccineId ?? this.vaccineId,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (institutionId.present) {
      map['institution_id'] = Variable<String>(institutionId.value);
    }
    if (vaccineId.present) {
      map['vaccine_id'] = Variable<String>(vaccineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstitutionVaccinesCacheCompanion(')
          ..write('id: $id, ')
          ..write('institutionId: $institutionId, ')
          ..write('vaccineId: $vaccineId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('category: $category, ')
          ..write('enabled: $enabled, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstitutionVaccineOptionsCacheTable
    extends InstitutionVaccineOptionsCache
    with
        TableInfo<
          $InstitutionVaccineOptionsCacheTable,
          InstitutionVaccineOptionsCacheData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstitutionVaccineOptionsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _vaccineIdMeta = const VerificationMeta(
    'vaccineId',
  );
  @override
  late final GeneratedColumn<String> vaccineId = GeneratedColumn<String>(
    'vaccine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldTypeMeta = const VerificationMeta(
    'fieldType',
  );
  @override
  late final GeneratedColumn<String> fieldType = GeneratedColumn<String>(
    'field_type',
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sourceTemplateIdMeta = const VerificationMeta(
    'sourceTemplateId',
  );
  @override
  late final GeneratedColumn<String> sourceTemplateId = GeneratedColumn<String>(
    'source_template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    institutionId,
    vaccineId,
    fieldType,
    value,
    displayName,
    sortOrder,
    isDefault,
    isActive,
    sourceTemplateId,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'institution_vaccine_options_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstitutionVaccineOptionsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('vaccine_id')) {
      context.handle(
        _vaccineIdMeta,
        vaccineId.isAcceptableOrUnknown(data['vaccine_id']!, _vaccineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vaccineIdMeta);
    }
    if (data.containsKey('field_type')) {
      context.handle(
        _fieldTypeMeta,
        fieldType.isAcceptableOrUnknown(data['field_type']!, _fieldTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldTypeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    } else if (isInserting) {
      context.missing(_isDefaultMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('source_template_id')) {
      context.handle(
        _sourceTemplateIdMeta,
        sourceTemplateId.isAcceptableOrUnknown(
          data['source_template_id']!,
          _sourceTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstitutionVaccineOptionsCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstitutionVaccineOptionsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      institutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_id'],
      )!,
      vaccineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vaccine_id'],
      )!,
      fieldType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      sourceTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_template_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $InstitutionVaccineOptionsCacheTable createAlias(String alias) {
    return $InstitutionVaccineOptionsCacheTable(attachedDatabase, alias);
  }
}

class InstitutionVaccineOptionsCacheData extends DataClass
    implements Insertable<InstitutionVaccineOptionsCacheData> {
  final String id;
  final String institutionId;
  final String vaccineId;
  final String fieldType;
  final String value;
  final String displayName;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final String? sourceTemplateId;
  final int version;
  const InstitutionVaccineOptionsCacheData({
    required this.id,
    required this.institutionId,
    required this.vaccineId,
    required this.fieldType,
    required this.value,
    required this.displayName,
    required this.sortOrder,
    required this.isDefault,
    required this.isActive,
    this.sourceTemplateId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['institution_id'] = Variable<String>(institutionId);
    map['vaccine_id'] = Variable<String>(vaccineId);
    map['field_type'] = Variable<String>(fieldType);
    map['value'] = Variable<String>(value);
    map['display_name'] = Variable<String>(displayName);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || sourceTemplateId != null) {
      map['source_template_id'] = Variable<String>(sourceTemplateId);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  InstitutionVaccineOptionsCacheCompanion toCompanion(bool nullToAbsent) {
    return InstitutionVaccineOptionsCacheCompanion(
      id: Value(id),
      institutionId: Value(institutionId),
      vaccineId: Value(vaccineId),
      fieldType: Value(fieldType),
      value: Value(value),
      displayName: Value(displayName),
      sortOrder: Value(sortOrder),
      isDefault: Value(isDefault),
      isActive: Value(isActive),
      sourceTemplateId: sourceTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTemplateId),
      version: Value(version),
    );
  }

  factory InstitutionVaccineOptionsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstitutionVaccineOptionsCacheData(
      id: serializer.fromJson<String>(json['id']),
      institutionId: serializer.fromJson<String>(json['institutionId']),
      vaccineId: serializer.fromJson<String>(json['vaccineId']),
      fieldType: serializer.fromJson<String>(json['fieldType']),
      value: serializer.fromJson<String>(json['value']),
      displayName: serializer.fromJson<String>(json['displayName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      sourceTemplateId: serializer.fromJson<String?>(json['sourceTemplateId']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'institutionId': serializer.toJson<String>(institutionId),
      'vaccineId': serializer.toJson<String>(vaccineId),
      'fieldType': serializer.toJson<String>(fieldType),
      'value': serializer.toJson<String>(value),
      'displayName': serializer.toJson<String>(displayName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isActive': serializer.toJson<bool>(isActive),
      'sourceTemplateId': serializer.toJson<String?>(sourceTemplateId),
      'version': serializer.toJson<int>(version),
    };
  }

  InstitutionVaccineOptionsCacheData copyWith({
    String? id,
    String? institutionId,
    String? vaccineId,
    String? fieldType,
    String? value,
    String? displayName,
    int? sortOrder,
    bool? isDefault,
    bool? isActive,
    Value<String?> sourceTemplateId = const Value.absent(),
    int? version,
  }) => InstitutionVaccineOptionsCacheData(
    id: id ?? this.id,
    institutionId: institutionId ?? this.institutionId,
    vaccineId: vaccineId ?? this.vaccineId,
    fieldType: fieldType ?? this.fieldType,
    value: value ?? this.value,
    displayName: displayName ?? this.displayName,
    sortOrder: sortOrder ?? this.sortOrder,
    isDefault: isDefault ?? this.isDefault,
    isActive: isActive ?? this.isActive,
    sourceTemplateId: sourceTemplateId.present
        ? sourceTemplateId.value
        : this.sourceTemplateId,
    version: version ?? this.version,
  );
  InstitutionVaccineOptionsCacheData copyWithCompanion(
    InstitutionVaccineOptionsCacheCompanion data,
  ) {
    return InstitutionVaccineOptionsCacheData(
      id: data.id.present ? data.id.value : this.id,
      institutionId: data.institutionId.present
          ? data.institutionId.value
          : this.institutionId,
      vaccineId: data.vaccineId.present ? data.vaccineId.value : this.vaccineId,
      fieldType: data.fieldType.present ? data.fieldType.value : this.fieldType,
      value: data.value.present ? data.value.value : this.value,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      sourceTemplateId: data.sourceTemplateId.present
          ? data.sourceTemplateId.value
          : this.sourceTemplateId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstitutionVaccineOptionsCacheData(')
          ..write('id: $id, ')
          ..write('institutionId: $institutionId, ')
          ..write('vaccineId: $vaccineId, ')
          ..write('fieldType: $fieldType, ')
          ..write('value: $value, ')
          ..write('displayName: $displayName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('isActive: $isActive, ')
          ..write('sourceTemplateId: $sourceTemplateId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    institutionId,
    vaccineId,
    fieldType,
    value,
    displayName,
    sortOrder,
    isDefault,
    isActive,
    sourceTemplateId,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstitutionVaccineOptionsCacheData &&
          other.id == this.id &&
          other.institutionId == this.institutionId &&
          other.vaccineId == this.vaccineId &&
          other.fieldType == this.fieldType &&
          other.value == this.value &&
          other.displayName == this.displayName &&
          other.sortOrder == this.sortOrder &&
          other.isDefault == this.isDefault &&
          other.isActive == this.isActive &&
          other.sourceTemplateId == this.sourceTemplateId &&
          other.version == this.version);
}

class InstitutionVaccineOptionsCacheCompanion
    extends UpdateCompanion<InstitutionVaccineOptionsCacheData> {
  final Value<String> id;
  final Value<String> institutionId;
  final Value<String> vaccineId;
  final Value<String> fieldType;
  final Value<String> value;
  final Value<String> displayName;
  final Value<int> sortOrder;
  final Value<bool> isDefault;
  final Value<bool> isActive;
  final Value<String?> sourceTemplateId;
  final Value<int> version;
  final Value<int> rowid;
  const InstitutionVaccineOptionsCacheCompanion({
    this.id = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.vaccineId = const Value.absent(),
    this.fieldType = const Value.absent(),
    this.value = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isActive = const Value.absent(),
    this.sourceTemplateId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstitutionVaccineOptionsCacheCompanion.insert({
    required String id,
    required String institutionId,
    required String vaccineId,
    required String fieldType,
    required String value,
    required String displayName,
    required int sortOrder,
    required bool isDefault,
    required bool isActive,
    this.sourceTemplateId = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       institutionId = Value(institutionId),
       vaccineId = Value(vaccineId),
       fieldType = Value(fieldType),
       value = Value(value),
       displayName = Value(displayName),
       sortOrder = Value(sortOrder),
       isDefault = Value(isDefault),
       isActive = Value(isActive),
       version = Value(version);
  static Insertable<InstitutionVaccineOptionsCacheData> custom({
    Expression<String>? id,
    Expression<String>? institutionId,
    Expression<String>? vaccineId,
    Expression<String>? fieldType,
    Expression<String>? value,
    Expression<String>? displayName,
    Expression<int>? sortOrder,
    Expression<bool>? isDefault,
    Expression<bool>? isActive,
    Expression<String>? sourceTemplateId,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (institutionId != null) 'institution_id': institutionId,
      if (vaccineId != null) 'vaccine_id': vaccineId,
      if (fieldType != null) 'field_type': fieldType,
      if (value != null) 'value': value,
      if (displayName != null) 'display_name': displayName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDefault != null) 'is_default': isDefault,
      if (isActive != null) 'is_active': isActive,
      if (sourceTemplateId != null) 'source_template_id': sourceTemplateId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstitutionVaccineOptionsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? institutionId,
    Value<String>? vaccineId,
    Value<String>? fieldType,
    Value<String>? value,
    Value<String>? displayName,
    Value<int>? sortOrder,
    Value<bool>? isDefault,
    Value<bool>? isActive,
    Value<String?>? sourceTemplateId,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return InstitutionVaccineOptionsCacheCompanion(
      id: id ?? this.id,
      institutionId: institutionId ?? this.institutionId,
      vaccineId: vaccineId ?? this.vaccineId,
      fieldType: fieldType ?? this.fieldType,
      value: value ?? this.value,
      displayName: displayName ?? this.displayName,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (institutionId.present) {
      map['institution_id'] = Variable<String>(institutionId.value);
    }
    if (vaccineId.present) {
      map['vaccine_id'] = Variable<String>(vaccineId.value);
    }
    if (fieldType.present) {
      map['field_type'] = Variable<String>(fieldType.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (sourceTemplateId.present) {
      map['source_template_id'] = Variable<String>(sourceTemplateId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstitutionVaccineOptionsCacheCompanion(')
          ..write('id: $id, ')
          ..write('institutionId: $institutionId, ')
          ..write('vaccineId: $vaccineId, ')
          ..write('fieldType: $fieldType, ')
          ..write('value: $value, ')
          ..write('displayName: $displayName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('isActive: $isActive, ')
          ..write('sourceTemplateId: $sourceTemplateId, ')
          ..write('version: $version, ')
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
  late final $VaccinesCacheTable vaccinesCache = $VaccinesCacheTable(this);
  late final $VaccineOptionsCacheTable vaccineOptionsCache =
      $VaccineOptionsCacheTable(this);
  late final $InstitutionVaccinesCacheTable institutionVaccinesCache =
      $InstitutionVaccinesCacheTable(this);
  late final $InstitutionVaccineOptionsCacheTable
  institutionVaccineOptionsCache = $InstitutionVaccineOptionsCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    currentUser,
    institutionsCache,
    usersCache,
    syncMetadata,
    vaccinesCache,
    vaccineOptionsCache,
    institutionVaccinesCache,
    institutionVaccineOptionsCache,
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
  Value<String?> documentType,
  Value<String?> documentNumber,
  Value<String?> phone,
  Value<String?> birthDate,
  Value<String?> gender,
  Value<String?> professionCode,
  Value<String?> professionalRegistrationNumber,
  Value<String?> professionalRegistrationType,
  Value<int> rowid,
});
typedef $$UsersCacheTableUpdateCompanionBuilder = UsersCacheCompanion Function({
  Value<String> id,
  Value<String> email,
  Value<String> fullName,
  Value<String> institutionId,
  Value<String> roles,
  Value<String> status,
  Value<String?> documentType,
  Value<String?> documentNumber,
  Value<String?> phone,
  Value<String?> birthDate,
  Value<String?> gender,
  Value<String?> professionCode,
  Value<String?> professionalRegistrationNumber,
  Value<String?> professionalRegistrationType,
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

  ColumnFilters<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get professionCode => $composableBuilder(
    column: $table.professionCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get professionalRegistrationNumber =>
      $composableBuilder(
        column: $table.professionalRegistrationNumber,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<String> get professionalRegistrationType => $composableBuilder(
    column: $table.professionalRegistrationType,
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

  ColumnOrderings<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get professionCode => $composableBuilder(
    column: $table.professionCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get professionalRegistrationNumber =>
      $composableBuilder(
        column: $table.professionalRegistrationNumber,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get professionalRegistrationType =>
      $composableBuilder(
        column: $table.professionalRegistrationType,
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

  GeneratedColumn<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get professionCode => $composableBuilder(
    column: $table.professionCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get professionalRegistrationNumber =>
      $composableBuilder(
        column: $table.professionalRegistrationNumber,
        builder: (column) => column,
      );

  GeneratedColumn<String> get professionalRegistrationType =>
      $composableBuilder(
        column: $table.professionalRegistrationType,
        builder: (column) => column,
      );
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
                Value<String?> documentType = const Value.absent(),
                Value<String?> documentNumber = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> professionCode = const Value.absent(),
                Value<String?> professionalRegistrationNumber =
                    const Value.absent(),
                Value<String?> professionalRegistrationType =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCacheCompanion(
                id: id,
                email: email,
                fullName: fullName,
                institutionId: institutionId,
                roles: roles,
                status: status,
                documentType: documentType,
                documentNumber: documentNumber,
                phone: phone,
                birthDate: birthDate,
                gender: gender,
                professionCode: professionCode,
                professionalRegistrationNumber: professionalRegistrationNumber,
                professionalRegistrationType: professionalRegistrationType,
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
                Value<String?> documentType = const Value.absent(),
                Value<String?> documentNumber = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> professionCode = const Value.absent(),
                Value<String?> professionalRegistrationNumber =
                    const Value.absent(),
                Value<String?> professionalRegistrationType =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCacheCompanion.insert(
                id: id,
                email: email,
                fullName: fullName,
                institutionId: institutionId,
                roles: roles,
                status: status,
                documentType: documentType,
                documentNumber: documentNumber,
                phone: phone,
                birthDate: birthDate,
                gender: gender,
                professionCode: professionCode,
                professionalRegistrationNumber: professionalRegistrationNumber,
                professionalRegistrationType: professionalRegistrationType,
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
typedef $$VaccinesCacheTableCreateCompanionBuilder =
    VaccinesCacheCompanion Function({
      required String id,
      required String name,
      required String code,
      required String category,
      required int maxDoses,
      Value<int?> minAgeMonths,
      Value<int?> maxAgeMonths,
      required bool active,
      required int version,
      Value<int> rowid,
    });
typedef $$VaccinesCacheTableUpdateCompanionBuilder =
    VaccinesCacheCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> code,
      Value<String> category,
      Value<int> maxDoses,
      Value<int?> minAgeMonths,
      Value<int?> maxAgeMonths,
      Value<bool> active,
      Value<int> version,
      Value<int> rowid,
    });

class $$VaccinesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $VaccinesCacheTable> {
  $$VaccinesCacheTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxDoses => $composableBuilder(
    column: $table.maxDoses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minAgeMonths => $composableBuilder(
    column: $table.minAgeMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxAgeMonths => $composableBuilder(
    column: $table.maxAgeMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaccinesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $VaccinesCacheTable> {
  $$VaccinesCacheTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxDoses => $composableBuilder(
    column: $table.maxDoses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minAgeMonths => $composableBuilder(
    column: $table.minAgeMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxAgeMonths => $composableBuilder(
    column: $table.maxAgeMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaccinesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaccinesCacheTable> {
  $$VaccinesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get maxDoses =>
      $composableBuilder(column: $table.maxDoses, builder: (column) => column);

  GeneratedColumn<int> get minAgeMonths => $composableBuilder(
    column: $table.minAgeMonths,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxAgeMonths => $composableBuilder(
    column: $table.maxAgeMonths,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$VaccinesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaccinesCacheTable,
          VaccinesCacheData,
          $$VaccinesCacheTableFilterComposer,
          $$VaccinesCacheTableOrderingComposer,
          $$VaccinesCacheTableAnnotationComposer,
          $$VaccinesCacheTableCreateCompanionBuilder,
          $$VaccinesCacheTableUpdateCompanionBuilder,
          (
            VaccinesCacheData,
            BaseReferences<
              _$AppDatabase,
              $VaccinesCacheTable,
              VaccinesCacheData
            >,
          ),
          VaccinesCacheData,
          PrefetchHooks Function()
        > {
  $$VaccinesCacheTableTableManager(_$AppDatabase db, $VaccinesCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaccinesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaccinesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaccinesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> maxDoses = const Value.absent(),
                Value<int?> minAgeMonths = const Value.absent(),
                Value<int?> maxAgeMonths = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaccinesCacheCompanion(
                id: id,
                name: name,
                code: code,
                category: category,
                maxDoses: maxDoses,
                minAgeMonths: minAgeMonths,
                maxAgeMonths: maxAgeMonths,
                active: active,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String code,
                required String category,
                required int maxDoses,
                Value<int?> minAgeMonths = const Value.absent(),
                Value<int?> maxAgeMonths = const Value.absent(),
                required bool active,
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => VaccinesCacheCompanion.insert(
                id: id,
                name: name,
                code: code,
                category: category,
                maxDoses: maxDoses,
                minAgeMonths: minAgeMonths,
                maxAgeMonths: maxAgeMonths,
                active: active,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaccinesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaccinesCacheTable,
      VaccinesCacheData,
      $$VaccinesCacheTableFilterComposer,
      $$VaccinesCacheTableOrderingComposer,
      $$VaccinesCacheTableAnnotationComposer,
      $$VaccinesCacheTableCreateCompanionBuilder,
      $$VaccinesCacheTableUpdateCompanionBuilder,
      (
        VaccinesCacheData,
        BaseReferences<_$AppDatabase, $VaccinesCacheTable, VaccinesCacheData>,
      ),
      VaccinesCacheData,
      PrefetchHooks Function()
    >;
typedef $$VaccineOptionsCacheTableCreateCompanionBuilder =
    VaccineOptionsCacheCompanion Function({
      required String id,
      required String vaccineId,
      required String fieldType,
      required String value,
      required String displayName,
      required int sortOrder,
      required bool isDefault,
      required bool isActive,
      Value<String?> sourceTemplateId,
      required int version,
      Value<int> rowid,
    });
typedef $$VaccineOptionsCacheTableUpdateCompanionBuilder =
    VaccineOptionsCacheCompanion Function({
      Value<String> id,
      Value<String> vaccineId,
      Value<String> fieldType,
      Value<String> value,
      Value<String> displayName,
      Value<int> sortOrder,
      Value<bool> isDefault,
      Value<bool> isActive,
      Value<String?> sourceTemplateId,
      Value<int> version,
      Value<int> rowid,
    });

class $$VaccineOptionsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $VaccineOptionsCacheTable> {
  $$VaccineOptionsCacheTableFilterComposer({
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

  ColumnFilters<String> get vaccineId => $composableBuilder(
    column: $table.vaccineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldType => $composableBuilder(
    column: $table.fieldType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaccineOptionsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $VaccineOptionsCacheTable> {
  $$VaccineOptionsCacheTableOrderingComposer({
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

  ColumnOrderings<String> get vaccineId => $composableBuilder(
    column: $table.vaccineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldType => $composableBuilder(
    column: $table.fieldType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaccineOptionsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaccineOptionsCacheTable> {
  $$VaccineOptionsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vaccineId =>
      $composableBuilder(column: $table.vaccineId, builder: (column) => column);

  GeneratedColumn<String> get fieldType =>
      $composableBuilder(column: $table.fieldType, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$VaccineOptionsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaccineOptionsCacheTable,
          VaccineOptionsCacheData,
          $$VaccineOptionsCacheTableFilterComposer,
          $$VaccineOptionsCacheTableOrderingComposer,
          $$VaccineOptionsCacheTableAnnotationComposer,
          $$VaccineOptionsCacheTableCreateCompanionBuilder,
          $$VaccineOptionsCacheTableUpdateCompanionBuilder,
          (
            VaccineOptionsCacheData,
            BaseReferences<
              _$AppDatabase,
              $VaccineOptionsCacheTable,
              VaccineOptionsCacheData
            >,
          ),
          VaccineOptionsCacheData,
          PrefetchHooks Function()
        > {
  $$VaccineOptionsCacheTableTableManager(
    _$AppDatabase db,
    $VaccineOptionsCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaccineOptionsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaccineOptionsCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VaccineOptionsCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vaccineId = const Value.absent(),
                Value<String> fieldType = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> sourceTemplateId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaccineOptionsCacheCompanion(
                id: id,
                vaccineId: vaccineId,
                fieldType: fieldType,
                value: value,
                displayName: displayName,
                sortOrder: sortOrder,
                isDefault: isDefault,
                isActive: isActive,
                sourceTemplateId: sourceTemplateId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vaccineId,
                required String fieldType,
                required String value,
                required String displayName,
                required int sortOrder,
                required bool isDefault,
                required bool isActive,
                Value<String?> sourceTemplateId = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => VaccineOptionsCacheCompanion.insert(
                id: id,
                vaccineId: vaccineId,
                fieldType: fieldType,
                value: value,
                displayName: displayName,
                sortOrder: sortOrder,
                isDefault: isDefault,
                isActive: isActive,
                sourceTemplateId: sourceTemplateId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaccineOptionsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaccineOptionsCacheTable,
      VaccineOptionsCacheData,
      $$VaccineOptionsCacheTableFilterComposer,
      $$VaccineOptionsCacheTableOrderingComposer,
      $$VaccineOptionsCacheTableAnnotationComposer,
      $$VaccineOptionsCacheTableCreateCompanionBuilder,
      $$VaccineOptionsCacheTableUpdateCompanionBuilder,
      (
        VaccineOptionsCacheData,
        BaseReferences<
          _$AppDatabase,
          $VaccineOptionsCacheTable,
          VaccineOptionsCacheData
        >,
      ),
      VaccineOptionsCacheData,
      PrefetchHooks Function()
    >;
typedef $$InstitutionVaccinesCacheTableCreateCompanionBuilder =
    InstitutionVaccinesCacheCompanion Function({
      required String id,
      required String institutionId,
      required String vaccineId,
      required String name,
      required String code,
      required String category,
      required bool enabled,
      required int version,
      Value<int> rowid,
    });
typedef $$InstitutionVaccinesCacheTableUpdateCompanionBuilder =
    InstitutionVaccinesCacheCompanion Function({
      Value<String> id,
      Value<String> institutionId,
      Value<String> vaccineId,
      Value<String> name,
      Value<String> code,
      Value<String> category,
      Value<bool> enabled,
      Value<int> version,
      Value<int> rowid,
    });

class $$InstitutionVaccinesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $InstitutionVaccinesCacheTable> {
  $$InstitutionVaccinesCacheTableFilterComposer({
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

  ColumnFilters<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaccineId => $composableBuilder(
    column: $table.vaccineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstitutionVaccinesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $InstitutionVaccinesCacheTable> {
  $$InstitutionVaccinesCacheTableOrderingComposer({
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

  ColumnOrderings<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaccineId => $composableBuilder(
    column: $table.vaccineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstitutionVaccinesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstitutionVaccinesCacheTable> {
  $$InstitutionVaccinesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vaccineId =>
      $composableBuilder(column: $table.vaccineId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$InstitutionVaccinesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstitutionVaccinesCacheTable,
          InstitutionVaccinesCacheData,
          $$InstitutionVaccinesCacheTableFilterComposer,
          $$InstitutionVaccinesCacheTableOrderingComposer,
          $$InstitutionVaccinesCacheTableAnnotationComposer,
          $$InstitutionVaccinesCacheTableCreateCompanionBuilder,
          $$InstitutionVaccinesCacheTableUpdateCompanionBuilder,
          (
            InstitutionVaccinesCacheData,
            BaseReferences<
              _$AppDatabase,
              $InstitutionVaccinesCacheTable,
              InstitutionVaccinesCacheData
            >,
          ),
          InstitutionVaccinesCacheData,
          PrefetchHooks Function()
        > {
  $$InstitutionVaccinesCacheTableTableManager(
    _$AppDatabase db,
    $InstitutionVaccinesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstitutionVaccinesCacheTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InstitutionVaccinesCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InstitutionVaccinesCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> institutionId = const Value.absent(),
                Value<String> vaccineId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstitutionVaccinesCacheCompanion(
                id: id,
                institutionId: institutionId,
                vaccineId: vaccineId,
                name: name,
                code: code,
                category: category,
                enabled: enabled,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String institutionId,
                required String vaccineId,
                required String name,
                required String code,
                required String category,
                required bool enabled,
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => InstitutionVaccinesCacheCompanion.insert(
                id: id,
                institutionId: institutionId,
                vaccineId: vaccineId,
                name: name,
                code: code,
                category: category,
                enabled: enabled,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstitutionVaccinesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstitutionVaccinesCacheTable,
      InstitutionVaccinesCacheData,
      $$InstitutionVaccinesCacheTableFilterComposer,
      $$InstitutionVaccinesCacheTableOrderingComposer,
      $$InstitutionVaccinesCacheTableAnnotationComposer,
      $$InstitutionVaccinesCacheTableCreateCompanionBuilder,
      $$InstitutionVaccinesCacheTableUpdateCompanionBuilder,
      (
        InstitutionVaccinesCacheData,
        BaseReferences<
          _$AppDatabase,
          $InstitutionVaccinesCacheTable,
          InstitutionVaccinesCacheData
        >,
      ),
      InstitutionVaccinesCacheData,
      PrefetchHooks Function()
    >;
typedef $$InstitutionVaccineOptionsCacheTableCreateCompanionBuilder =
    InstitutionVaccineOptionsCacheCompanion Function({
      required String id,
      required String institutionId,
      required String vaccineId,
      required String fieldType,
      required String value,
      required String displayName,
      required int sortOrder,
      required bool isDefault,
      required bool isActive,
      Value<String?> sourceTemplateId,
      required int version,
      Value<int> rowid,
    });
typedef $$InstitutionVaccineOptionsCacheTableUpdateCompanionBuilder =
    InstitutionVaccineOptionsCacheCompanion Function({
      Value<String> id,
      Value<String> institutionId,
      Value<String> vaccineId,
      Value<String> fieldType,
      Value<String> value,
      Value<String> displayName,
      Value<int> sortOrder,
      Value<bool> isDefault,
      Value<bool> isActive,
      Value<String?> sourceTemplateId,
      Value<int> version,
      Value<int> rowid,
    });

class $$InstitutionVaccineOptionsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $InstitutionVaccineOptionsCacheTable> {
  $$InstitutionVaccineOptionsCacheTableFilterComposer({
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

  ColumnFilters<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaccineId => $composableBuilder(
    column: $table.vaccineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldType => $composableBuilder(
    column: $table.fieldType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstitutionVaccineOptionsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $InstitutionVaccineOptionsCacheTable> {
  $$InstitutionVaccineOptionsCacheTableOrderingComposer({
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

  ColumnOrderings<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaccineId => $composableBuilder(
    column: $table.vaccineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldType => $composableBuilder(
    column: $table.fieldType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstitutionVaccineOptionsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstitutionVaccineOptionsCacheTable> {
  $$InstitutionVaccineOptionsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vaccineId =>
      $composableBuilder(column: $table.vaccineId, builder: (column) => column);

  GeneratedColumn<String> get fieldType =>
      $composableBuilder(column: $table.fieldType, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get sourceTemplateId => $composableBuilder(
    column: $table.sourceTemplateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$InstitutionVaccineOptionsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstitutionVaccineOptionsCacheTable,
          InstitutionVaccineOptionsCacheData,
          $$InstitutionVaccineOptionsCacheTableFilterComposer,
          $$InstitutionVaccineOptionsCacheTableOrderingComposer,
          $$InstitutionVaccineOptionsCacheTableAnnotationComposer,
          $$InstitutionVaccineOptionsCacheTableCreateCompanionBuilder,
          $$InstitutionVaccineOptionsCacheTableUpdateCompanionBuilder,
          (
            InstitutionVaccineOptionsCacheData,
            BaseReferences<
              _$AppDatabase,
              $InstitutionVaccineOptionsCacheTable,
              InstitutionVaccineOptionsCacheData
            >,
          ),
          InstitutionVaccineOptionsCacheData,
          PrefetchHooks Function()
        > {
  $$InstitutionVaccineOptionsCacheTableTableManager(
    _$AppDatabase db,
    $InstitutionVaccineOptionsCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstitutionVaccineOptionsCacheTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InstitutionVaccineOptionsCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InstitutionVaccineOptionsCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> institutionId = const Value.absent(),
                Value<String> vaccineId = const Value.absent(),
                Value<String> fieldType = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> sourceTemplateId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstitutionVaccineOptionsCacheCompanion(
                id: id,
                institutionId: institutionId,
                vaccineId: vaccineId,
                fieldType: fieldType,
                value: value,
                displayName: displayName,
                sortOrder: sortOrder,
                isDefault: isDefault,
                isActive: isActive,
                sourceTemplateId: sourceTemplateId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String institutionId,
                required String vaccineId,
                required String fieldType,
                required String value,
                required String displayName,
                required int sortOrder,
                required bool isDefault,
                required bool isActive,
                Value<String?> sourceTemplateId = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => InstitutionVaccineOptionsCacheCompanion.insert(
                id: id,
                institutionId: institutionId,
                vaccineId: vaccineId,
                fieldType: fieldType,
                value: value,
                displayName: displayName,
                sortOrder: sortOrder,
                isDefault: isDefault,
                isActive: isActive,
                sourceTemplateId: sourceTemplateId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstitutionVaccineOptionsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstitutionVaccineOptionsCacheTable,
      InstitutionVaccineOptionsCacheData,
      $$InstitutionVaccineOptionsCacheTableFilterComposer,
      $$InstitutionVaccineOptionsCacheTableOrderingComposer,
      $$InstitutionVaccineOptionsCacheTableAnnotationComposer,
      $$InstitutionVaccineOptionsCacheTableCreateCompanionBuilder,
      $$InstitutionVaccineOptionsCacheTableUpdateCompanionBuilder,
      (
        InstitutionVaccineOptionsCacheData,
        BaseReferences<
          _$AppDatabase,
          $InstitutionVaccineOptionsCacheTable,
          InstitutionVaccineOptionsCacheData
        >,
      ),
      InstitutionVaccineOptionsCacheData,
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
  $$VaccinesCacheTableTableManager get vaccinesCache =>
      $$VaccinesCacheTableTableManager(_db, _db.vaccinesCache);
  $$VaccineOptionsCacheTableTableManager get vaccineOptionsCache =>
      $$VaccineOptionsCacheTableTableManager(_db, _db.vaccineOptionsCache);
  $$InstitutionVaccinesCacheTableTableManager get institutionVaccinesCache =>
      $$InstitutionVaccinesCacheTableTableManager(
        _db,
        _db.institutionVaccinesCache,
      );
  $$InstitutionVaccineOptionsCacheTableTableManager
  get institutionVaccineOptionsCache =>
      $$InstitutionVaccineOptionsCacheTableTableManager(
        _db,
        _db.institutionVaccineOptionsCache,
      );
}
