// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_dao.dart';

// ignore_for_file: type=lint
mixin _$PrinterDaoMixin on DatabaseAccessor<AppDatabase> {
  $PrintersTable get printers => attachedDatabase.printers;
  PrinterDaoManager get managers => PrinterDaoManager(this);
}

class PrinterDaoManager {
  final _$PrinterDaoMixin _db;
  PrinterDaoManager(this._db);
  $$PrintersTableTableManager get printers =>
      $$PrintersTableTableManager(_db.attachedDatabase, _db.printers);
}
