/// 打印机配置 DAO - CRUD 操作
library;

import 'package:drift/drift.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_type.dart';

import 'database.dart';

part 'printer_dao.g.dart';

/// 打印机配置数据访问对象
@DriftAccessor(tables: [Printers])
class PrinterDao extends DatabaseAccessor<AppDatabase>
    with _$PrinterDaoMixin {
  PrinterDao(super.db);

  /// 获取所有打印机
  Future<List<PrinterConfig>> getAllPrinters() async {
    final rows = await select(printers).get();
    return rows.map(_toConfig).toList();
  }

  /// 监听所有打印机（响应式）
  Stream<List<PrinterConfig>> watchAllPrinters() {
    return select(printers).watch().map(
          (rows) => rows.map(_toConfig).toList(),
        );
  }

  /// 按 ID 获取打印机
  Future<PrinterConfig?> getPrinterById(int id) async {
    final row = await (select(printers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _toConfig(row) : null;
  }

  /// 按序列号获取打印机
  Future<PrinterConfig?> getPrinterBySerial(String serial) async {
    final row = await (select(printers)
          ..where((t) => t.serial.equals(serial)))
        .getSingleOrNull();
    return row != null ? _toConfig(row) : null;
  }

  /// 插入新打印机，返回自增 ID
  Future<int> insertPrinter(PrinterConfig config) async {
    final companion = PrintersCompanion(
      name: Value(config.name),
      ip: Value(config.ip),
      serial: Value(config.serial),
      accessCode: Value(config.accessCode),
      useTls: Value(config.useTls),
      printerType: Value(config.printerType.value),
      aiConfidenceThreshold: Value(config.aiConfidenceThreshold),
      aiMaxConsecutive: Value(config.aiMaxConsecutive),
      aiAutoPause: Value(config.aiAutoPause),
      lastConnected: Value(config.lastConnected),
      createdAt: Value(config.createdAt ?? DateTime.now()),
    );
    return await into(printers).insert(companion);
  }

  /// 更新打印机
  Future<bool> updatePrinter(PrinterConfig config) async {
    if (config.id == null) return false;
    final rowsAffected = await (update(printers)
          ..where((t) => t.id.equals(config.id!)))
        .write(PrintersCompanion(
      name: Value(config.name),
      ip: Value(config.ip),
      serial: Value(config.serial),
      accessCode: Value(config.accessCode),
      useTls: Value(config.useTls),
      printerType: Value(config.printerType.value),
      aiConfidenceThreshold: Value(config.aiConfidenceThreshold),
      aiMaxConsecutive: Value(config.aiMaxConsecutive),
      aiAutoPause: Value(config.aiAutoPause),
      lastConnected: Value(config.lastConnected),
    ));
    return rowsAffected > 0;
  }

  /// 更新最后连接时间
  Future<bool> updateLastConnected(int id, DateTime time) async {
    final rowsAffected = await (update(printers)
          ..where((t) => t.id.equals(id)))
        .write(PrintersCompanion(
      lastConnected: Value(time),
    ));
    return rowsAffected > 0;
  }

  /// 删除打印机
  Future<bool> deletePrinter(int id) async {
    final rowsAffected =
        await (delete(printers)..where((t) => t.id.equals(id))).go();
    return rowsAffected > 0;
  }

  /// 删除所有打印机
  Future<int> deleteAll() async {
    return await delete(printers).go();
  }

  /// 数据库行转模型
  PrinterConfig _toConfig(Printer row) {
    return PrinterConfig(
      id: row.id,
      name: row.name,
      ip: row.ip,
      serial: row.serial,
      accessCode: row.accessCode,
      useTls: row.useTls,
      printerType: PrinterType.fromValue(row.printerType),
      aiConfidenceThreshold: row.aiConfidenceThreshold,
      aiMaxConsecutive: row.aiMaxConsecutive,
      aiAutoPause: row.aiAutoPause,
      lastConnected: row.lastConnected,
      createdAt: row.createdAt,
    );
  }
}
