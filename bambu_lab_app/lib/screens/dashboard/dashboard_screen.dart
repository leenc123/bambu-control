/// 打印机控制面板 - 主界面（左侧导航 + Tab 切换）软拟物风格
library;

import 'package:flutter/material.dart';
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
import 'package:bambu_lab_app/widgets/neuo_button.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _idx = 0;

  static const _dests = [
    (label: '设备总览', icon: LucideIcons.layoutDashboard, selIcon: LucideIcons.layoutDashboard),
    (label: '控制', icon: LucideIcons.slidersHorizontal, selIcon: LucideIcons.slidersHorizontal),
    (label: 'AMS', icon: LucideIcons.packageOpen, selIcon: LucideIcons.packageOpen),
    (label: '文件', icon: LucideIcons.folderOpen, selIcon: LucideIcons.folderOpen),
    (label: '设置', icon: LucideIcons.settings, selIcon: LucideIcons.settings),
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
                      child: NeuoCard(
                        shape: _idx == i ? NeuoShape.concave : NeuoShape.convex,
                        borderRadius: 16,
                        depth: _idx == i ? 3 : 5,
                        intensity: _idx == i ? 0.5 : 0.65,
                        padding: const EdgeInsets.all(12),
                        onTap: () => setState(() => _idx = i),
                        child: Icon(
                          _idx == i ? _dests[i].selIcon : _dests[i].icon,
                          color: _idx == i ? c.accent : c.textSecondary,
                          size: 24,
                        ),
                      ),
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

class _DisconnectedView extends StatelessWidget {
  const _DisconnectedView({required this.c});
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        NeuoCard(
          shape: NeuoShape.convex, borderRadius: 44, depth: 6, intensity: 0.65,
          padding: const EdgeInsets.all(24),
          child: Icon(LucideIcons.wifiOff, size: 48, color: c.textSecondary.withValues(alpha: 0.35)),
        ),
        const SizedBox(height: 16),
        Text('未连接到打印机', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 14),
        NeuoButton(
          label: const Text('返回主页'), depth: 5, intensity: 0.75,
          onPressed: () => context.go('/'),
        ),
      ]),
    );
  }
}
