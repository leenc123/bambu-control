/// 调试日志弹窗（全局可用）
library;

import 'package:flutter/material.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';

/// 在任何页面调用此函数即可弹出调试日志
void showDebugLog(BuildContext context) {
  final c = NeuoTheme.of(context);
  final logs = DebugLog.all;
  showModalBottomSheet(
    backgroundColor: c.background,
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.35,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('MQTT 调试日志', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const Spacer(),
            Text('${logs.length} 条', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () { DebugLog.clear(); },
              child: Text('清空', style: TextStyle(fontSize: 13, color: c.accent)),
            ),
          ]),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('暂无日志 — 连接打印机后 MQTT 日志会自动记录', style: TextStyle(fontSize: 13, color: c.textSecondary))))
          else
            ...logs.reversed.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(e.formatted,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: c.textPrimary)),
            )),
        ]),
      ),
    ),
  );
}
