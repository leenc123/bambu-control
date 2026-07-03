// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PrintersTable extends Printers with TableInfo<$PrintersTable, Printer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrintersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 7,
      maxTextLength: 45,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  @override
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
    'serial',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessCodeMeta = const VerificationMeta(
    'accessCode',
  );
  @override
  late final GeneratedColumn<String> accessCode = GeneratedColumn<String>(
    'access_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _useTlsMeta = const VerificationMeta('useTls');
  @override
  late final GeneratedColumn<bool> useTls = GeneratedColumn<bool>(
    'use_tls',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_tls" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _printerTypeMeta = const VerificationMeta(
    'printerType',
  );
  @override
  late final GeneratedColumn<String> printerType = GeneratedColumn<String>(
    'printer_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNKNOWN'),
  );
  static const VerificationMeta _lastConnectedMeta = const VerificationMeta(
    'lastConnected',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnected =
      GeneratedColumn<DateTime>(
        'last_connected',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ip,
    serial,
    accessCode,
    useTls,
    printerType,
    lastConnected,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'printers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Printer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('serial')) {
      context.handle(
        _serialMeta,
        serial.isAcceptableOrUnknown(data['serial']!, _serialMeta),
      );
    } else if (isInserting) {
      context.missing(_serialMeta);
    }
    if (data.containsKey('access_code')) {
      context.handle(
        _accessCodeMeta,
        accessCode.isAcceptableOrUnknown(data['access_code']!, _accessCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_accessCodeMeta);
    }
    if (data.containsKey('use_tls')) {
      context.handle(
        _useTlsMeta,
        useTls.isAcceptableOrUnknown(data['use_tls']!, _useTlsMeta),
      );
    }
    if (data.containsKey('printer_type')) {
      context.handle(
        _printerTypeMeta,
        printerType.isAcceptableOrUnknown(
          data['printer_type']!,
          _printerTypeMeta,
        ),
      );
    }
    if (data.containsKey('last_connected')) {
      context.handle(
        _lastConnectedMeta,
        lastConnected.isAcceptableOrUnknown(
          data['last_connected']!,
          _lastConnectedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Printer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Printer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      serial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serial'],
      )!,
      accessCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_code'],
      )!,
      useTls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_tls'],
      )!,
      printerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printer_type'],
      )!,
      lastConnected: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PrintersTable createAlias(String alias) {
    return $PrintersTable(attachedDatabase, alias);
  }
}

class Printer extends DataClass implements Insertable<Printer> {
  final int id;
  final String name;
  final String ip;
  final String serial;
  final String accessCode;
  final bool useTls;
  final String printerType;
  final DateTime? lastConnected;
  final DateTime createdAt;
  const Printer({
    required this.id,
    required this.name,
    required this.ip,
    required this.serial,
    required this.accessCode,
    required this.useTls,
    required this.printerType,
    this.lastConnected,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['ip'] = Variable<String>(ip);
    map['serial'] = Variable<String>(serial);
    map['access_code'] = Variable<String>(accessCode);
    map['use_tls'] = Variable<bool>(useTls);
    map['printer_type'] = Variable<String>(printerType);
    if (!nullToAbsent || lastConnected != null) {
      map['last_connected'] = Variable<DateTime>(lastConnected);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PrintersCompanion toCompanion(bool nullToAbsent) {
    return PrintersCompanion(
      id: Value(id),
      name: Value(name),
      ip: Value(ip),
      serial: Value(serial),
      accessCode: Value(accessCode),
      useTls: Value(useTls),
      printerType: Value(printerType),
      lastConnected: lastConnected == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnected),
      createdAt: Value(createdAt),
    );
  }

  factory Printer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Printer(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ip: serializer.fromJson<String>(json['ip']),
      serial: serializer.fromJson<String>(json['serial']),
      accessCode: serializer.fromJson<String>(json['accessCode']),
      useTls: serializer.fromJson<bool>(json['useTls']),
      printerType: serializer.fromJson<String>(json['printerType']),
      lastConnected: serializer.fromJson<DateTime?>(json['lastConnected']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'ip': serializer.toJson<String>(ip),
      'serial': serializer.toJson<String>(serial),
      'accessCode': serializer.toJson<String>(accessCode),
      'useTls': serializer.toJson<bool>(useTls),
      'printerType': serializer.toJson<String>(printerType),
      'lastConnected': serializer.toJson<DateTime?>(lastConnected),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Printer copyWith({
    int? id,
    String? name,
    String? ip,
    String? serial,
    String? accessCode,
    bool? useTls,
    String? printerType,
    Value<DateTime?> lastConnected = const Value.absent(),
    DateTime? createdAt,
  }) => Printer(
    id: id ?? this.id,
    name: name ?? this.name,
    ip: ip ?? this.ip,
    serial: serial ?? this.serial,
    accessCode: accessCode ?? this.accessCode,
    useTls: useTls ?? this.useTls,
    printerType: printerType ?? this.printerType,
    lastConnected: lastConnected.present
        ? lastConnected.value
        : this.lastConnected,
    createdAt: createdAt ?? this.createdAt,
  );
  Printer copyWithCompanion(PrintersCompanion data) {
    return Printer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ip: data.ip.present ? data.ip.value : this.ip,
      serial: data.serial.present ? data.serial.value : this.serial,
      accessCode: data.accessCode.present
          ? data.accessCode.value
          : this.accessCode,
      useTls: data.useTls.present ? data.useTls.value : this.useTls,
      printerType: data.printerType.present
          ? data.printerType.value
          : this.printerType,
      lastConnected: data.lastConnected.present
          ? data.lastConnected.value
          : this.lastConnected,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Printer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ip: $ip, ')
          ..write('serial: $serial, ')
          ..write('accessCode: $accessCode, ')
          ..write('useTls: $useTls, ')
          ..write('printerType: $printerType, ')
          ..write('lastConnected: $lastConnected, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ip,
    serial,
    accessCode,
    useTls,
    printerType,
    lastConnected,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Printer &&
          other.id == this.id &&
          other.name == this.name &&
          other.ip == this.ip &&
          other.serial == this.serial &&
          other.accessCode == this.accessCode &&
          other.useTls == this.useTls &&
          other.printerType == this.printerType &&
          other.lastConnected == this.lastConnected &&
          other.createdAt == this.createdAt);
}

class PrintersCompanion extends UpdateCompanion<Printer> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> ip;
  final Value<String> serial;
  final Value<String> accessCode;
  final Value<bool> useTls;
  final Value<String> printerType;
  final Value<DateTime?> lastConnected;
  final Value<DateTime> createdAt;
  const PrintersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ip = const Value.absent(),
    this.serial = const Value.absent(),
    this.accessCode = const Value.absent(),
    this.useTls = const Value.absent(),
    this.printerType = const Value.absent(),
    this.lastConnected = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PrintersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String ip,
    required String serial,
    required String accessCode,
    this.useTls = const Value.absent(),
    this.printerType = const Value.absent(),
    this.lastConnected = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       ip = Value(ip),
       serial = Value(serial),
       accessCode = Value(accessCode),
       createdAt = Value(createdAt);
  static Insertable<Printer> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? ip,
    Expression<String>? serial,
    Expression<String>? accessCode,
    Expression<bool>? useTls,
    Expression<String>? printerType,
    Expression<DateTime>? lastConnected,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ip != null) 'ip': ip,
      if (serial != null) 'serial': serial,
      if (accessCode != null) 'access_code': accessCode,
      if (useTls != null) 'use_tls': useTls,
      if (printerType != null) 'printer_type': printerType,
      if (lastConnected != null) 'last_connected': lastConnected,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PrintersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? ip,
    Value<String>? serial,
    Value<String>? accessCode,
    Value<bool>? useTls,
    Value<String>? printerType,
    Value<DateTime?>? lastConnected,
    Value<DateTime>? createdAt,
  }) {
    return PrintersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      serial: serial ?? this.serial,
      accessCode: accessCode ?? this.accessCode,
      useTls: useTls ?? this.useTls,
      printerType: printerType ?? this.printerType,
      lastConnected: lastConnected ?? this.lastConnected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (accessCode.present) {
      map['access_code'] = Variable<String>(accessCode.value);
    }
    if (useTls.present) {
      map['use_tls'] = Variable<bool>(useTls.value);
    }
    if (printerType.present) {
      map['printer_type'] = Variable<String>(printerType.value);
    }
    if (lastConnected.present) {
      map['last_connected'] = Variable<DateTime>(lastConnected.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrintersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ip: $ip, ')
          ..write('serial: $serial, ')
          ..write('accessCode: $accessCode, ')
          ..write('useTls: $useTls, ')
          ..write('printerType: $printerType, ')
          ..write('lastConnected: $lastConnected, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DebugLogEntriesTable extends DebugLogEntries
    with TableInfo<$DebugLogEntriesTable, DebugLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebugLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, time, tag, message];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debug_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebugLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebugLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebugLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}time'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
    );
  }

  @override
  $DebugLogEntriesTable createAlias(String alias) {
    return $DebugLogEntriesTable(attachedDatabase, alias);
  }
}

class DebugLogEntry extends DataClass implements Insertable<DebugLogEntry> {
  final int id;
  final DateTime time;
  final String tag;
  final String message;
  const DebugLogEntry({
    required this.id,
    required this.time,
    required this.tag,
    required this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['time'] = Variable<DateTime>(time);
    map['tag'] = Variable<String>(tag);
    map['message'] = Variable<String>(message);
    return map;
  }

  DebugLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return DebugLogEntriesCompanion(
      id: Value(id),
      time: Value(time),
      tag: Value(tag),
      message: Value(message),
    );
  }

  factory DebugLogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebugLogEntry(
      id: serializer.fromJson<int>(json['id']),
      time: serializer.fromJson<DateTime>(json['time']),
      tag: serializer.fromJson<String>(json['tag']),
      message: serializer.fromJson<String>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'time': serializer.toJson<DateTime>(time),
      'tag': serializer.toJson<String>(tag),
      'message': serializer.toJson<String>(message),
    };
  }

  DebugLogEntry copyWith({
    int? id,
    DateTime? time,
    String? tag,
    String? message,
  }) => DebugLogEntry(
    id: id ?? this.id,
    time: time ?? this.time,
    tag: tag ?? this.tag,
    message: message ?? this.message,
  );
  DebugLogEntry copyWithCompanion(DebugLogEntriesCompanion data) {
    return DebugLogEntry(
      id: data.id.present ? data.id.value : this.id,
      time: data.time.present ? data.time.value : this.time,
      tag: data.tag.present ? data.tag.value : this.tag,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebugLogEntry(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('tag: $tag, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, time, tag, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebugLogEntry &&
          other.id == this.id &&
          other.time == this.time &&
          other.tag == this.tag &&
          other.message == this.message);
}

class DebugLogEntriesCompanion extends UpdateCompanion<DebugLogEntry> {
  final Value<int> id;
  final Value<DateTime> time;
  final Value<String> tag;
  final Value<String> message;
  const DebugLogEntriesCompanion({
    this.id = const Value.absent(),
    this.time = const Value.absent(),
    this.tag = const Value.absent(),
    this.message = const Value.absent(),
  });
  DebugLogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime time,
    required String tag,
    required String message,
  }) : time = Value(time),
       tag = Value(tag),
       message = Value(message);
  static Insertable<DebugLogEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? time,
    Expression<String>? tag,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (time != null) 'time': time,
      if (tag != null) 'tag': tag,
      if (message != null) 'message': message,
    });
  }

  DebugLogEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? time,
    Value<String>? tag,
    Value<String>? message,
  }) {
    return DebugLogEntriesCompanion(
      id: id ?? this.id,
      time: time ?? this.time,
      tag: tag ?? this.tag,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebugLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('time: $time, ')
          ..write('tag: $tag, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PrintersTable printers = $PrintersTable(this);
  late final $DebugLogEntriesTable debugLogEntries = $DebugLogEntriesTable(
    this,
  );
  late final PrinterDao printerDao = PrinterDao(this as AppDatabase);
  late final DebugLogDao debugLogDao = DebugLogDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    printers,
    debugLogEntries,
  ];
}

typedef $$PrintersTableCreateCompanionBuilder =
    PrintersCompanion Function({
      Value<int> id,
      required String name,
      required String ip,
      required String serial,
      required String accessCode,
      Value<bool> useTls,
      Value<String> printerType,
      Value<DateTime?> lastConnected,
      required DateTime createdAt,
    });
typedef $$PrintersTableUpdateCompanionBuilder =
    PrintersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> ip,
      Value<String> serial,
      Value<String> accessCode,
      Value<bool> useTls,
      Value<String> printerType,
      Value<DateTime?> lastConnected,
      Value<DateTime> createdAt,
    });

class $$PrintersTableFilterComposer
    extends Composer<_$AppDatabase, $PrintersTable> {
  $$PrintersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serial => $composableBuilder(
    column: $table.serial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessCode => $composableBuilder(
    column: $table.accessCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useTls => $composableBuilder(
    column: $table.useTls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get printerType => $composableBuilder(
    column: $table.printerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnected => $composableBuilder(
    column: $table.lastConnected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrintersTableOrderingComposer
    extends Composer<_$AppDatabase, $PrintersTable> {
  $$PrintersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serial => $composableBuilder(
    column: $table.serial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessCode => $composableBuilder(
    column: $table.accessCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useTls => $composableBuilder(
    column: $table.useTls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get printerType => $composableBuilder(
    column: $table.printerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnected => $composableBuilder(
    column: $table.lastConnected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrintersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrintersTable> {
  $$PrintersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<String> get accessCode => $composableBuilder(
    column: $table.accessCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useTls =>
      $composableBuilder(column: $table.useTls, builder: (column) => column);

  GeneratedColumn<String> get printerType => $composableBuilder(
    column: $table.printerType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastConnected => $composableBuilder(
    column: $table.lastConnected,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PrintersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrintersTable,
          Printer,
          $$PrintersTableFilterComposer,
          $$PrintersTableOrderingComposer,
          $$PrintersTableAnnotationComposer,
          $$PrintersTableCreateCompanionBuilder,
          $$PrintersTableUpdateCompanionBuilder,
          (Printer, BaseReferences<_$AppDatabase, $PrintersTable, Printer>),
          Printer,
          PrefetchHooks Function()
        > {
  $$PrintersTableTableManager(_$AppDatabase db, $PrintersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrintersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrintersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrintersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String> serial = const Value.absent(),
                Value<String> accessCode = const Value.absent(),
                Value<bool> useTls = const Value.absent(),
                Value<String> printerType = const Value.absent(),
                Value<DateTime?> lastConnected = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PrintersCompanion(
                id: id,
                name: name,
                ip: ip,
                serial: serial,
                accessCode: accessCode,
                useTls: useTls,
                printerType: printerType,
                lastConnected: lastConnected,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String ip,
                required String serial,
                required String accessCode,
                Value<bool> useTls = const Value.absent(),
                Value<String> printerType = const Value.absent(),
                Value<DateTime?> lastConnected = const Value.absent(),
                required DateTime createdAt,
              }) => PrintersCompanion.insert(
                id: id,
                name: name,
                ip: ip,
                serial: serial,
                accessCode: accessCode,
                useTls: useTls,
                printerType: printerType,
                lastConnected: lastConnected,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrintersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrintersTable,
      Printer,
      $$PrintersTableFilterComposer,
      $$PrintersTableOrderingComposer,
      $$PrintersTableAnnotationComposer,
      $$PrintersTableCreateCompanionBuilder,
      $$PrintersTableUpdateCompanionBuilder,
      (Printer, BaseReferences<_$AppDatabase, $PrintersTable, Printer>),
      Printer,
      PrefetchHooks Function()
    >;
typedef $$DebugLogEntriesTableCreateCompanionBuilder =
    DebugLogEntriesCompanion Function({
      Value<int> id,
      required DateTime time,
      required String tag,
      required String message,
    });
typedef $$DebugLogEntriesTableUpdateCompanionBuilder =
    DebugLogEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> time,
      Value<String> tag,
      Value<String> message,
    });

class $$DebugLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DebugLogEntriesTable> {
  $$DebugLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebugLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DebugLogEntriesTable> {
  $$DebugLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebugLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebugLogEntriesTable> {
  $$DebugLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$DebugLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebugLogEntriesTable,
          DebugLogEntry,
          $$DebugLogEntriesTableFilterComposer,
          $$DebugLogEntriesTableOrderingComposer,
          $$DebugLogEntriesTableAnnotationComposer,
          $$DebugLogEntriesTableCreateCompanionBuilder,
          $$DebugLogEntriesTableUpdateCompanionBuilder,
          (
            DebugLogEntry,
            BaseReferences<_$AppDatabase, $DebugLogEntriesTable, DebugLogEntry>,
          ),
          DebugLogEntry,
          PrefetchHooks Function()
        > {
  $$DebugLogEntriesTableTableManager(
    _$AppDatabase db,
    $DebugLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebugLogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebugLogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebugLogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> time = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> message = const Value.absent(),
              }) => DebugLogEntriesCompanion(
                id: id,
                time: time,
                tag: tag,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime time,
                required String tag,
                required String message,
              }) => DebugLogEntriesCompanion.insert(
                id: id,
                time: time,
                tag: tag,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebugLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebugLogEntriesTable,
      DebugLogEntry,
      $$DebugLogEntriesTableFilterComposer,
      $$DebugLogEntriesTableOrderingComposer,
      $$DebugLogEntriesTableAnnotationComposer,
      $$DebugLogEntriesTableCreateCompanionBuilder,
      $$DebugLogEntriesTableUpdateCompanionBuilder,
      (
        DebugLogEntry,
        BaseReferences<_$AppDatabase, $DebugLogEntriesTable, DebugLogEntry>,
      ),
      DebugLogEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PrintersTableTableManager get printers =>
      $$PrintersTableTableManager(_db, _db.printers);
  $$DebugLogEntriesTableTableManager get debugLogEntries =>
      $$DebugLogEntriesTableTableManager(_db, _db.debugLogEntries);
}
