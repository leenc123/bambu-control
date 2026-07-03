/// 设置 Tab（使用 flutter_neumorphism_ui）
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/version.dart';
import 'package:bambu_lab_app/providers/theme_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/printer_image.dart';
import 'package:bambu_lab_app/utils/debug_log_viewer.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sec('打印机', c),
        const SizedBox(height: 8),
        const _InfoCard(),
        const SizedBox(height: 14),
        _sec('应用', c),
        const SizedBox(height: 8),
        _TileBtn(icon: LucideIcons.info, title: '关于', subtitle: 'Bambu Lab App v$appVersion', c: c, onTap: () => showAboutDialog(
            context: context, applicationName: 'Bambu Lab App', applicationVersion: appVersion, applicationLegalese: 'Powered by Flutter')),
        const SizedBox(height: 6),
        _TileBtn(icon: LucideIcons.bug, title: '调试信息', subtitle: '查看连接和状态详情', c: c, onTap: () => showDebugLog(context)),
        const SizedBox(height: 14),
        _sec('外观', c),
        const SizedBox(height: 8),
        const _ThemeSelector(),
        const SizedBox(height: 14),
        _sec('操作', c),
        const SizedBox(height: 8),
        _TileBtn(icon: LucideIcons.pencil, title: '管理打印机', subtitle: '添加、编辑或删除打印机配置', c: c, onTap: () => context.go('/')),
        const SizedBox(height: 6),
        _TileBtn(icon: LucideIcons.logOut, title: '断开连接', subtitle: '断开后自动返回打印机管理页面', c: c, onTap: () async {
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

        return FlutterNeumorphism(
          style: NeumorphismStyle(color: c.background, borderRadius: 16, depth: 5),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
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

// ---- 可点击卡片按钮 ----
class _TileBtn extends StatefulWidget {
  const _TileBtn({required this.icon, required this.title, required this.subtitle, required this.c, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final NeuoColors c;
  final VoidCallback onTap;

  @override
  State<_TileBtn> createState() => _TileBtnState();
}

class _TileBtnState extends State<_TileBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 14,
          depth: _pressed ? 3 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.c.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 18, color: widget.c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.textPrimary)),
              Text(widget.subtitle, style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
            ]),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: widget.c.textSecondary.withValues(alpha: 0.5)),
        ]),
      ),
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
            child: _ThemeBtn(mode: opt.$1, icon: opt.$2, label: opt.$3, selected: cur == opt.$1, onTap: () => tp.mode = opt.$1, c: c),
          ),
        ),
    ]);
  }
}

// ---- 主题按钮 ----
class _ThemeBtn extends StatefulWidget {
  const _ThemeBtn({required this.mode, required this.icon, required this.label, required this.selected, required this.onTap, required this.c});
  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final NeuoColors c;

  @override
  State<_ThemeBtn> createState() => _ThemeBtnState();
}

class _ThemeBtnState extends State<_ThemeBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 12,
          depth: _pressed ? 2 : (widget.selected ? 3 : 5),
          type: _pressed ? NeumorphismType.pressed : (widget.selected ? NeumorphismType.pressed : NeumorphismType.flat),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Icon(widget.icon, size: 22,
              color: widget.selected ? widget.c.accent : widget.c.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 4),
          Text(widget.label, style: TextStyle(fontSize: 11,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: widget.selected ? widget.c.accent : widget.c.textSecondary)),
        ]),
      ),
    );
  }
}