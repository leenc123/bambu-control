/// Drift 数据库定义 - 打印机配置存储
library;

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';

import 'printer_dao.dart';
import 'debug_log_dao.dart';

part 'database.g.dart';

/// 打印机配置表
class Printers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  TextColumn get ip => text().withLength(min: 7, max: 45)();
  TextColumn get serial => text().withLength(min: 1, max: 32)();
  TextColumn get accessCode => text().withLength(min: 1, max: 32)();
  BoolColumn get useTls => boolean().withDefault(const Constant(true))();
  TextColumn get printerType =>
      text().withDefault(const Constant('UNKNOWN'))();
  DateTimeColumn get lastConnected => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 调试日志表
class DebugLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  TextColumn get tag => text().withLength(min: 1, max: 32)();
  TextColumn get message => text()();
}

/// 应用数据库
@DriftDatabase(tables: [Printers, DebugLogEntries], daos: [PrinterDao, DebugLogDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 -> v2: 添加 use_tls 列（默认 true = 使用 TLS）
            await m.database.customStatement(
              'ALTER TABLE printers ADD COLUMN use_tls INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (from < 3) {
            // v2 -> v3: 添加 printer_type 列（默认 UNKNOWN）
            await m.database.customStatement(
              "ALTER TABLE printers ADD COLUMN printer_type TEXT NOT NULL DEFAULT 'UNKNOWN'",
            );
          }
          if (from < 4) {
            // v3 -> v4: 添加调试日志表
            await m.createTable(debugLogEntries);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(docsDir.path, 'bambu_lab_app.sqlite'));
      return NativeDatabase.createInBackground(
        file,
        // Linux 下手动指定系统 sqlite3 库。
        // 必须在 isolateSetup 里设置：createInBackground 在独立 isolate
        // 打开数据库，主 isolate 里的 overrideFor 对那边不可见
        // （drift 文档：isolate 内无法访问主 isolate 的全局变量）。
        // 若不加，sqlite3 包会误以为插件已把 sqlite3 打进进程，
        // 从进程符号表查找 sqlite3_libversion_number 而失败。
        isolateSetup: () {
          if (Platform.isLinux) {
            try {
              open.overrideFor(
                OperatingSystem.linux,
                () => DynamicLibrary.open('libsqlite3.so.0'),
              );
            } catch (_) {
              open.overrideFor(
                OperatingSystem.linux,
                () => DynamicLibrary.open('libsqlite3.so'),
              );
            }
          }
        },
      );
    });
  }
}
