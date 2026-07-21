/// 调试日志弹窗 — 实时更新 + 导出分享文件
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';

/// 在任何页面调用此函数即可弹出实时调试日志
void showDebugLog(BuildContext context) {
  Navigator.of(context).push(_DebugLogRoute());
}

/// 自定义路由：背景透明，可下拉关闭
class _DebugLogRoute extends PopupRoute {
  @override
  Color? get barrierColor => Colors.black54;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => '关闭调试日志';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _DebugLogPage(animation: animation);
  }
}

class _DebugLogPage extends StatefulWidget {
  final Animation<double> animation;
  const _DebugLogPage({required this.animation});

  @override
  State<_DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<_DebugLogPage> {
  Timer? _refreshTimer;
  final ScrollController _scrollCtrl = ScrollController();
  int _logCount = DebugLog.all.length;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // 每 500ms 检查日志有无更新
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final current = DebugLog.all.length;
      if (current != _logCount) {
        setState(() {
          _logCount = current;
        });
        // 新日志到达时自动滚到底部
        if (_autoScroll && _scrollCtrl.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.animateTo(
                _scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _shareLogs() async {
    try {
      final logs = DebugLog.all;
      final text = logs.reversed.map((e) => e.formatted).join('\n');

      // 写入临时文件
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bambu_debug_log_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(text);

      // 使用系统分享
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Bambu Lab App 调试日志',
        text: '共 ${logs.length} 条日志',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  void _clearLogs() {
    DebugLog.clear();
    setState(() {
      _logCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    final logs = DebugLog.all;
    final displayLogs = logs.reversed.toList();

    return FadeTransition(
      opacity: widget.animation,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 60),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade800.withValues(alpha: 0.3))),
                ),
                child: Row(children: [
                  Text('调试日志', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  const SizedBox(width: 8),
                  Text('$_logCount 条', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  const Spacer(),
                  // 自动滚动开关
                  GestureDetector(
                    onTap: () => setState(() => _autoScroll = !_autoScroll),
                    child: Icon(
                      _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                      size: 18,
                      color: _autoScroll ? c.accent : c.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 分享
                  GestureDetector(
                    onTap: _shareLogs,
                    child: Text('分享', style: TextStyle(fontSize: 13, color: c.accent)),
                  ),
                  const SizedBox(width: 10),
                  // 清空
                  GestureDetector(
                    onTap: _clearLogs,
                    child: Text('清空', style: TextStyle(fontSize: 13, color: c.accent)),
                  ),
                  const SizedBox(width: 8),
                  // 关闭
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, size: 20, color: c.textSecondary),
                  ),
                ]),
              ),
              // 日志列表
              Expanded(
                child: _logCount == 0
                    ? Center(
                        child: Text('暂无日志 — 连接打印机后日志会自动记录',
                            style: TextStyle(fontSize: 13, color: c.textSecondary)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: displayLogs.length,
                        itemBuilder: (_, i) {
                          final e = displayLogs[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(e.formatted,
                                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: c.textPrimary)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
