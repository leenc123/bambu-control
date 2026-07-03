// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debug_log_dao.dart';

// ignore_for_file: type=lint
mixin _$DebugLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $DebugLogEntriesTable get debugLogEntries => attachedDatabase.debugLogEntries;
  DebugLogDaoManager get managers => DebugLogDaoManager(this);
}

class DebugLogDaoManager {
  final _$DebugLogDaoMixin _db;
  DebugLogDaoManager(this._db);
  $$DebugLogEntriesTableTableManager get debugLogEntries =>
      $$DebugLogEntriesTableTableManager(
        _db.attachedDatabase,
        _db.debugLogEntries,
      );
}
