/// 打印机控制面板 - 主界面（使用 flutter_neumorphism_ui）
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/ams_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/control_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/overview_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/files_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/settings_tab.dart';
import 'package:bambu_lab_app/screens/dashboard/tabs/ai_tab.dart';import 'package:bambu_lab_app/theme/neuo_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _idx = 0;
  bool _connecting = false;
  String? _connectError;

  static const _dests = [
    ('设备总览', LucideIcons.layoutDashboard),
    ('控制', LucideIcons.slidersHorizontal),
    ('AMS', LucideIcons.packageOpen),
    ('文件', LucideIcons.folderOpen),
    ('AI', LucideIcons.cpu),
    ('设置', LucideIcons.settings),
  ];

  @override
  void initState() {
    super.initState();
    // 进入主界面后自动连接已配置设备
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConnected());
  }

  /// 自动连接已配置设备；失败后由状态视图提供 重试/修改设置
  Future<void> _ensureConnected() async {
    final pp = context.read<PrinterProvider>();
    if (pp.isConnected || _connecting) return;
    final cp = context.read<PrinterConfigProvider>();
    final cfg = cp.selected ?? (cp.printers.isNotEmpty ? cp.printers.first : null);
    if (cfg == null) return; // 未配置设备：状态视图显示配置引导
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    cp.selectPrinter(cfg);
    pp.onPrinterTypeDetected = (type) {
      final cur = cp.printers.isNotEmpty ? cp.printers.first : null;
      if (cur != null) cp.updatePrinter(cur.copyWith(printerType: type));
    };
    bool ok = false;
    bool timedOut = false;
    try {
      ok = await pp.connect(cfg).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      timedOut = true;
    }
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connectError =
          ok ? null : (timedOut ? '连接超时，请检查打印机是否在线' : (pp.errorMessage ?? '连接失败'));
    });
  }

  /// 打开设备配置页（编辑当前设备；无设备则新建）
  void _openConnect() {
    final cp = context.read<PrinterConfigProvider>();
    final id = cp.selected?.id ?? (cp.printers.isNotEmpty ? cp.printers.first.id : null);
    if (id != null) {
      context.push('/connect/$id');
    } else {
      context.push('/connect');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: Consumer<PrinterProvider>(
        builder: (_, printer, __) {
          if (!printer.isConnected) {
            return _ConnectStateView(
              c: c,
              connecting: _connecting,
              hasConfig:
                  context.read<PrinterConfigProvider>().printers.isNotEmpty,
              error: _connectError,
              onRetry: _ensureConnected,
              onConfigure: _openConnect,
            );
          }
          return Row(
            // 撑满高度：内容矮的 Tab（如 AI 配置）不会被垂直居中
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
            ],
          );
        },
      ),
    );
  }

  Widget _tab(PrinterProvider p) => switch (_idx) {
    0 => OverviewTab(printer: p),
    1 => ControlTab(printer: p),
    2 => const AmsTab(),
    3 => const FilesTab(),
    4 => const AiTab(),
    5 => const SettingsTab(),
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
          color: widget.c.background,
          borderRadius: 12,
          depth: _pressed ? 2 : (widget.selected ? 3 : 5),
          type: _pressed ? NeumorphismType.pressed : (widget.selected ? NeumorphismType.pressed : NeumorphismType.flat),
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(widget.icon, color: widget.selected ? widget.c.accent : widget.c.textSecondary.withValues(alpha: 0.5), size: 22),
      ),
    );
  }
}

// ---- 连接状态视图（连接中 / 未配置 / 连接失败）----
class _ConnectStateView extends StatelessWidget {
  const _ConnectStateView({
    required this.c,
    required this.connecting,
    required this.hasConfig,
    required this.error,
    required this.onRetry,
    required this.onConfigure,
  });

  final NeuoColors c;
  final bool connecting;
  final bool hasConfig;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    if (connecting) {
      return Center(
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: c.background,
            borderRadius: 44,
            depth: 4,
            type: NeumorphismType.pressed,
          ),
          padding: const EdgeInsets.all(18),
          child: const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    final IconData icon;
    final String title;
    final String msg;
    if (hasConfig) {
      icon = LucideIcons.wifiOff;
      title = '未连接到打印机';
      msg = error ?? '请重试或修改设备设置';
    } else {
      icon = LucideIcons.printer;
      title = '未配置设备';
      msg = '请先添加打印机连接信息';
    }

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FlutterNeumorphism(
          style: NeumorphismStyle(color: c.background, borderRadius: 44, depth: 6),
          padding: const EdgeInsets.all(24),
          child: Icon(icon, size: 48, color: c.textSecondary.withValues(alpha: 0.35)),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 6),
        Text(msg, style: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.7))),
        const SizedBox(height: 18),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasConfig) ...[
            _StateButton(label: '重试', icon: LucideIcons.rotateCw, c: c, onTap: onRetry),
            const SizedBox(width: 10),
            _StateButton(label: '修改设置', icon: LucideIcons.pencil, accent: true, c: c, onTap: onConfigure),
          ] else
            _StateButton(label: '配置设备', icon: LucideIcons.plus, accent: true, c: c, onTap: onConfigure),
        ]),
      ]),
    );
  }
}

// ---- 状态操作按钮 ----
class _StateButton extends StatefulWidget {
  const _StateButton({
    required this.label,
    required this.icon,
    required this.c,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final bool accent;
  final VoidCallback onTap;
  final NeuoColors c;

  @override
  State<_StateButton> createState() => _StateButtonState();
}

class _StateButtonState extends State<_StateButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accent ? widget.c.accent : widget.c.textSecondary;
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
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(widget.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}