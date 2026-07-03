/// 调试日志 — 内存环形缓存 + 数据库持久化
library;

import 'dart:collection';

import 'package:bambu_lab_app/db/database.dart';

/// 日志条目
class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  const LogEntry(this.time, this.tag, this.message);

  String get formatted =>
      '[${time.toString().substring(11, 23)}][$tag] $message';
}

/// 全局调试日志（内存最多保留 200 条 + 数据库持久化）
class DebugLog {
  DebugLog._();

  static final _logs = Queue<LogEntry>();
  static const _max = 200;
  static AppDatabase? _db;

  /// 设置数据库实例（main.dart 启动时调用）
  static void setDatabase(AppDatabase db) {
    _db = db;
  }

  /// 记录日志（同时写入内存和数据库）
  static void i(String tag, String msg) {
    final entry = LogEntry(DateTime.now(), tag, msg);
    _logs.add(entry);
    while (_logs.length > _max) { _logs.removeFirst(); }
    // 异步写入数据库，不阻塞主线程
    _db?.debugLogDao.addLog(entry.time, entry.tag, entry.message);
  }

  /// 初始化（供 main.dart 启动时调用）
  static void init() {
    i('APP', 'App 已启动');
    i('APP', 'DebugLog 系统就绪');
  }

  /// 获取内存中的日志
  static List<LogEntry> get all => _logs.toList(growable: false);

  /// 清空内存日志
  static void clear() => _logs.clear();

  /// 清空数据库日志
  static Future<void> clearDb() async {
    await _db?.debugLogDao.clearAllLogs();
  }

  /// 从数据库加载历史日志到内存
  static Future<void> loadFromDb() async {
    if (_db == null) return;
    final dbLogs = await _db!.debugLogDao.getRecentLogs(_max);
    _logs.clear();
    for (final e in dbLogs) {
      _logs.add(LogEntry(e.time, e.tag, e.message));
    }
  }

  /// 导出日志为文本
  static Future<String> exportAsText() async {
    if (_db == null) return all.reversed.map((e) => e.formatted).join('\n');
    return await _db!.debugLogDao.exportAsText();
  }
}
