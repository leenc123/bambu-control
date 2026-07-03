/// 打印机控制面板 - 主界面（使用 flutter_neumorphism_ui）
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/ams_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/control_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/overview_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/files_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/settings_tab.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _idx = 0;

  static const _dests = [
    ('设备总览', LucideIcons.layoutDashboard),
    ('控制', LucideIcons.slidersHorizontal),
    ('AMS', LucideIcons.packageOpen),
    ('文件', LucideIcons.folderOpen),
    ('设置', LucideIcons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: Consumer<PrinterProvider>(
        builder: (_, printer, __) {
          if (!printer.isConnected) return _DisconnectedView(c: c);
          return Row(children: [
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: c.background,
              child: Column(
                children: [
                  for (int i = 0; i < _dests.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: _NavItem(icon: _dests[i].$2, selected: _idx == i, onPressed: () => setState(() => _idx = i), c: c),
                    ),
                  ],
                ],
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: c.textSecondary.withValues(alpha: 0.12)),
            Expanded(child: _tab(printer)),
          ]);
        },
      ),
    );
  }

  Widget _tab(PrinterProvider p) => switch (_idx) {
    0 => OverviewTab(printer: p),
    1 => ControlTab(printer: p),
    2 => const AmsTab(),
    3 => const FilesTab(),
    4 => const SettingsTab(),
    _ => OverviewTab(printer: p),
  };
}

// ---- 导航按钮 ----
class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, required this.selected, required this.onPressed, required this.c});
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.selected ? widget.c.accent.withValues(alpha: 0.15) : widget.c.background,
          borderRadius: 16,
          depth: _pressed ? 2 : (widget.selected ? 3 : 5),
          type: _pressed ? NeumorphismType.pressed : (widget.selected ? NeumorphismType.pressed : NeumorphismType.flat),
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(widget.icon, color: widget.selected ? widget.c.accent : widget.c.textSecondary, size: 24),
      ),
    );
  }
}

// ---- 断开连接视图 ----
class _DisconnectedView extends StatelessWidget {
  const _DisconnectedView({required this.c});
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FlutterNeumorphism(
          style: NeumorphismStyle(color: c.background, borderRadius: 44, depth: 6),
          padding: const EdgeInsets.all(24),
          child: Icon(LucideIcons.wifiOff, size: 48, color: c.textSecondary.withValues(alpha: 0.35)),
        ),
        const SizedBox(height: 16),
        Text('未连接到打印机', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 14),
        _BackHomeButton(c: c),
      ]),
    );
  }
}

// ---- 返回主页按钮 ----
class _BackHomeButton extends StatefulWidget {
  const _BackHomeButton({required this.c});
  final NeuoColors c;

  @override
  State<_BackHomeButton> createState() => _BackHomeButtonState();
}

class _BackHomeButtonState extends State<_BackHomeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.go('/');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 14,
          depth: _pressed ? 3 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text('返回主页', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.textSecondary)),
      ),
    );
  }
}