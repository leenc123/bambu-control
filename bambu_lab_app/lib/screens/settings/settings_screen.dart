/// 应用设置（软拟物风格）
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/utils/debug_log_viewer.dart';
import 'package:bambu_lab_app/version.dart';
import 'package:bambu_lab_app/providers/theme_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          ListView(padding: const EdgeInsets.fromLTRB(0, 40, 0, 8), children: [
        _section('打印机', c),
        const _PrinterInfoTile(),
        _divider(c),
        _section('应用', c),
        _tile(LucideIcons.info, '关于', 'Bambu Lab App v$appVersion', c, () => showAboutDialog(
              context: context,
              applicationName: 'Bambu Lab App',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Powered by Flutter',
            )),
        _divider(c),
        _tile(LucideIcons.bug, '调试信息', '查看连接和状态详情', c, () => _showDebugInfo(context, c)),
        _divider(c),
        _section('外观', c),
        _ThemeSelector(c: c),
        _divider(c),
        _section('操作', c),
        _tile(LucideIcons.pencil, '管理打印机', '添加、编辑或删除打印机配置', c, () => context.go('/')),
        _divider(c),
        _tile(LucideIcons.logOut, '断开连接', '断开当前打印机连接', c, () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('断开连接'),
              content: const Text('确定要断开与打印机的连接吗？'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('断开', style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            await context.read<PrinterProvider>().disconnect();
            if (context.mounted) context.go('/');
          }
        }),
      ]),
        ],
      ),
    );
  }

  Widget _section(String t, NeuoColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent)),
      );

  Widget _divider(NeuoColors c) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: c.textSecondary.withValues(alpha: 0.12)));

  Widget _tile(IconData icon, String title, String? subtitle, NeuoColors c, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: c.accent),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: c.textSecondary)) : null,
        trailing: Icon(LucideIcons.chevronRight, color: c.textSecondary),
        onTap: onTap,
      );
}

class _PrinterInfoTile extends StatelessWidget {
  const _PrinterInfoTile();

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Consumer<PrinterProvider>(
      builder: (_, printer, __) {
        final ok = printer.isConnected;
        final s = printer.state;
        return ListTile(
          leading: Icon(ok ? Icons.wifi : LucideIcons.wifiOff, color: ok ? Colors.green : c.textSecondary),
          title: Text(ok ? '已连接' : '未连接',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary)),
          subtitle: ok
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (s.serialNumber != null) Text('序列号: ${s.serialNumber}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  if (s.firmwareVersion != null) Text('固件: ${s.firmwareVersion}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  if (s.wifiSignal != null) Text('WiFi: ${s.wifiSignal}dBm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ])
              : Text('请先连接打印机', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          trailing: Icon(ok ? LucideIcons.circleCheck : LucideIcons.circleX,
              color: ok ? Colors.green : c.textSecondary, size: 20),
        );
      },
    );
  }
}

void _showDebugInfo(BuildContext context, NeuoColors c) {
  showDebugLog(context);
}



class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.c});
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeModeProvider>();
    final current = tp.mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        for (final opt in [
          (ThemeMode.system, Icons.brightness_auto, '跟随系统'),
          (ThemeMode.light, Icons.light_mode, '浅色'),
          (ThemeMode.dark, Icons.dark_mode, '深色'),
        ])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: opt.$1 == ThemeMode.system ? 0 : 6,
                right: opt.$1 == ThemeMode.dark ? 0 : 6,
              ),
              child: NeuoCard(
                onTap: () => tp.mode = opt.$1,
                depth: current == opt.$1 ? 1 : 4,
                intensity: 0.6,
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: 14,
                child: Column(children: [
                  Icon(opt.$2,
                      size: 24,
                      color: current == opt.$1 ? c.accent : c.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 6),
                  Text(opt.$3,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: current == opt.$1 ? FontWeight.w600 : FontWeight.w400,
                          color: current == opt.$1 ? c.accent : c.textSecondary)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
