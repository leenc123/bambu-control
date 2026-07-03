/// 调试日志 DAO - 日志存储与导出
library;

import 'package:drift/drift.dart';

import 'database.dart';

part 'debug_log_dao.g.dart';

/// 调试日志数据访问对象
@DriftAccessor(tables: [DebugLogEntries])
class DebugLogDao extends DatabaseAccessor<AppDatabase>
    with _$DebugLogDaoMixin {
  DebugLogDao(super.db);

  /// 添加日志条目
  Future<int> addLog(DateTime time, String tag, String message) async {
    return await into(debugLogEntries).insert(DebugLogEntriesCompanion(
      time: Value(time),
      tag: Value(tag),
      message: Value(message),
    ));
  }

  /// 获取所有日志（按时间倒序）
  Future<List<DebugLogEntry>> getAllLogs() async {
    return await (select(debugLogEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  /// 获取最近 N 条日志
  Future<List<DebugLogEntry>> getRecentLogs(int limit) async {
    return await (select(debugLogEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.time)])
          ..limit(limit))
        .get();
  }

  /// 监听日志变化（响应式）
  Stream<List<DebugLogEntry>> watchLogs({int? limit}) {
    final query = select(debugLogEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.time)]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  /// 按标签筛选日志
  Future<List<DebugLogEntry>> getLogsByTag(String tag) async {
    return await (select(debugLogEntries)
          ..where((t) => t.tag.equals(tag))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  /// 清空所有日志
  Future<int> clearAllLogs() async {
    return await delete(debugLogEntries).go();
  }

  /// 删除超过指定数量的旧日志
  Future<int> pruneOldLogs(int keepCount) async {
    final all = await getAllLogs();
    if (all.length <= keepCount) return 0;

    final toDelete = all.skip(keepCount).map((e) => e.id).toList();
    var deleted = 0;
    for (final id in toDelete) {
      deleted += await (delete(debugLogEntries)..where((t) => t.id.equals(id))).go();
    }
    return deleted;
  }

  /// 导出日志为文本格式
  Future<String> exportAsText() async {
    final logs = await getAllLogs();
    final lines = logs.map((e) =>
      '[${e.time.toIso8601String()}][${e.tag}] ${e.message}'
    ).toList();
    return lines.join('\n');
  }

  /// 获取日志总数
  Future<int> getLogCount() async {
    return await debugLogEntries.count().getSingle();
  }
}