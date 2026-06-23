/// 设置 Tab（拟物卡片风格）
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/version.dart';
import 'package:bambu_lab_app/providers/theme_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/printer_image.dart';
import 'package:bambu_lab_app/utils/debug_log_viewer.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ---- 打印机 ----
        _sec('打印机', c),
        const SizedBox(height: 8),
        const _InfoCard(),

        const SizedBox(height: 14),

        // ---- 应用 ----
        _sec('应用', c),
        const SizedBox(height: 8),
        _cardTile(LucideIcons.info, '关于', 'Bambu Lab App v$appVersion', c, () => showAboutDialog(
            context: context, applicationName: 'Bambu Lab App', applicationVersion: appVersion, applicationLegalese: 'Powered by Flutter')),
        const SizedBox(height: 6),
        _cardTile(LucideIcons.bug, '调试信息', '查看连接和状态详情', c, () => _debug(context, c)),

        const SizedBox(height: 14),

        // ---- 外观 ----
        _sec('外观', c),
        const SizedBox(height: 8),
        const _ThemeSelector(),

        const SizedBox(height: 14),

        // ---- 操作 ----
        _sec('操作', c),
        const SizedBox(height: 8),
        _cardTile(LucideIcons.pencil, '管理打印机', '添加、编辑或删除打印机配置', c, () => context.go('/')),
        const SizedBox(height: 6),
        _cardTile(LucideIcons.logOut, '断开连接', '断开后自动返回打印机管理页面', c, () async {
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('断开连接'), content: const Text('确定要断开与打印机的连接吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('断开', style: TextStyle(color: Colors.red))),
            ],
          ));
          if (ok == true && context.mounted) {
            await context.read<PrinterProvider>().disconnect();
            if (context.mounted) context.go('/');
          }
        }),
      ],
    );
  }

  Widget _sec(String t, NeuoColors c) => Align(
      alignment: Alignment.centerLeft,
      child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)));

  Widget _cardTile(IconData icon, String title, String subtitle, NeuoColors c, VoidCallback onTap) => NeuoCard(
        onTap: onTap, borderRadius: 14, depth: 4, intensity: 0.55,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          NeuoCard(shape: NeuoShape.concave, borderRadius: 10, depth: 2, intensity: 0.35, padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 18, color: c.accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ])),
          Icon(LucideIcons.chevronRight, size: 18, color: c.textSecondary.withValues(alpha: 0.5)),
        ]),
      );
}

// ---- 打印机信息卡片 ----
class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Consumer<PrinterProvider>(
      builder: (_, printer, __) {
        final ok = printer.isConnected;
        final s = printer.state;
        final img = printerImageByType(s.printerType);

        return NeuoCard(
          borderRadius: 16, depth: 5, intensity: 0.65,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // 型号图
            if (img != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(img, width: 48, height: 34, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: ok ? Colors.green : c.textSecondary,
                          boxShadow: ok ? [BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 4)] : [])),
                  const SizedBox(width: 6),
                  Text(ok ? '已连接' : '未连接',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ok ? Colors.green : c.textSecondary)),
                ]),
                const SizedBox(height: 4),
                if (ok) ...[
                  Row(children: [
                    Icon(LucideIcons.printer, size: 12, color: c.textSecondary), const SizedBox(width: 4),
                    Text(s.printerType.displayName, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    const SizedBox(width: 10),
                    Icon(LucideIcons.wifi, size: 12, color: c.textSecondary), const SizedBox(width: 3),
                    Text('${s.wifiSignal ?? "--"}dBm', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 3),
                  Text('固件: ${s.firmwareVersion ?? "--"}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ],
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ---- 主题选择 ----
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    final tp = context.watch<ThemeModeProvider>();
    final cur = tp.mode;

    return Row(children: [
      for (final opt in [
        (ThemeMode.system, LucideIcons.monitor, '跟随系统'),
        (ThemeMode.light, LucideIcons.sun, '浅色'),
        (ThemeMode.dark, LucideIcons.moon, '深色'),
      ])
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: opt.$1 == ThemeMode.system ? 0 : 4, right: opt.$1 == ThemeMode.dark ? 0 : 4),
            child: NeuoCard(
              onTap: () => tp.mode = opt.$1,
              shape: cur == opt.$1 ? NeuoShape.concave : NeuoShape.convex,
              borderRadius: 12, depth: cur == opt.$1 ? 2 : 4, intensity: 0.55,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Icon(opt.$2, size: 22,
                    color: cur == opt.$1 ? c.accent : c.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 4),
                Text(opt.$3, style: TextStyle(fontSize: 11,
                    fontWeight: cur == opt.$1 ? FontWeight.w600 : FontWeight.w400,
                    color: cur == opt.$1 ? c.accent : c.textSecondary)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

// ---- 调试弹窗 ----
void _debug(BuildContext context, NeuoColors c) {
  showDebugLog(context);
}
