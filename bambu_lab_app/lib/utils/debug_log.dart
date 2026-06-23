/// 调试日志 — 内存环形缓存
library;

import 'dart:collection';

/// 日志条目
class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  const LogEntry(this.time, this.tag, this.message);

  String get formatted =>
      '[${time.toString().substring(11, 23)}][$tag] $message';
}

/// 全局调试日志（最多保留 200 条）
class DebugLog {
  DebugLog._();

  static final _logs = Queue<LogEntry>();
  static const _max = 200;

  static void i(String tag, String msg) {
    _logs.add(LogEntry(DateTime.now(), tag, msg));
    while (_logs.length > _max) { _logs.removeFirst(); }
  }

  /// 初始化（供 main.dart 启动时调用）
  static void init() {
    i('APP', 'App 已启动');
    i('APP', 'DebugLog 系统就绪');
  }

  static List<LogEntry> get all => _logs.toList(growable: false);
  static void clear() => _logs.clear();
}
