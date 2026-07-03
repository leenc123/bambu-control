/// 主页 - 打印机列表（使用 flutter_neumorphism_ui）
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/printer_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _connecting = false;  // 防抖：正在连接时不允许再次点击

  @override
  void initState() {
    super.initState();
    context.read<PrinterConfigProvider>().startPingLoop();
  }

  @override
  void dispose() {
    context.read<PrinterConfigProvider>().stopPingLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Consumer<PrinterConfigProvider>(
        builder: (_, cp, __) {
          if (cp.isLoading) return const Center(child: _LoadingView());
          if (cp.error != null) return _ErrorView(msg: cp.error!, onRetry: () => cp.loadPrinters(), c: c);
          final list = cp.printers;
          if (list.isEmpty) return const _EmptyView();
          return RefreshIndicator(
            onRefresh: () => cp.loadPrinters(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 78),
              itemCount: list.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PrinterTile(
                  printer: list[i],
                  isOnline: cp.isOnline(list[i].id),
                  onTap: () => _tap(context, cp, list[i]),
                  onDelete: () => _del(context, cp, list[i]),
                  disabled: _connecting,  // 连接中禁用点击
                  c: c,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: _AddButton(onPressed: () => context.push('/connect'), c: c),
    );
  }

  Future<void> _tap(BuildContext ctx, PrinterConfigProvider cp, PrinterConfig p) async {
    if (_connecting) return;

    setState(() => _connecting = true);

    // 显示连接中的提示（与超时时间对齐）
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('正在连接 ${p.name}...'),
        ]),
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    cp.selectPrinter(p);
    final pp = ctx.read<PrinterProvider>();
    pp.onPrinterTypeDetected = (type) {
      final cfg = p.copyWith(printerType: type);
      cp.updatePrinter(cfg);
    };

    bool ok = false;
    bool timedOut = false;
    try {
      // 30 秒超时，防止 connect() 永远挂起导致 UI 卡死
      ok = await pp.connect(p).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      timedOut = true;
    } finally {
      // 无论成功、失败、超时，都确保解锁列表
      if (ctx.mounted) setState(() => _connecting = false);
    }

    if (!ctx.mounted) return;

    // 清除连接提示
    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();

    if (ok) {
      ctx.go('/dashboard');
    } else {
      _err(ctx, timedOut ? '连接超时，请检查打印机是否在线' : (pp.errorMessage ?? '连接失败'));
    }
  }

  Future<void> _del(BuildContext ctx, PrinterConfigProvider cp, PrinterConfig p) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除打印机 "${p.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && p.id != null) await cp.deletePrinter(p.id!);
  }

  void _err(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}

// ---- 添加按钮 ----
class _AddButton extends StatefulWidget {
  const _AddButton({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 2, right: 2),
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: widget.c.accent.withValues(alpha: 0.12),
            borderRadius: 16,
            depth: _pressed ? 3 : 6,
            type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.plus, size: 20, color: widget.c.accent),
            const SizedBox(width: 8),
            Text('添加', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.accent)),
          ]),
        ),
      ),
    );
  }
}

// ---- 打印机卡片 ----
class _PrinterTile extends StatefulWidget {
  const _PrinterTile({required this.printer, required this.isOnline, required this.onTap, required this.onDelete, required this.disabled, required this.c});
  final PrinterConfig printer;
  final bool isOnline;
  final bool disabled;  // 禁用状态
  final VoidCallback onTap, onDelete;
  final NeuoColors c;

  @override
  State<_PrinterTile> createState() => _PrinterTileState();
}

class _PrinterTileState extends State<_PrinterTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isDisabled = widget.disabled;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled ? null : (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,  // 禁用时降低透明度
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: c.background,
            borderRadius: 16,
            depth: _pressed ? 3 : 6,
            type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.2)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 3)],
              ),
            ),
            const SizedBox(width: 12),
            _DeviceIcon(type: widget.printer.printerType, c: c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.printer.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: (widget.isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.4), blurRadius: 3)],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(widget.printer.ip, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ]),
            ),
            const SizedBox(width: 2),
            _MenuButton(printer: widget.printer, onDelete: widget.onDelete, disabled: isDisabled, c: c),
          ]),
        ),
      ),
    );
  }
}

// ---- 菜单按钮 ----
class _MenuButton extends StatefulWidget {
  const _MenuButton({required this.printer, required this.onDelete, required this.disabled, required this.c});
  final PrinterConfig printer;
  final VoidCallback onDelete;
  final bool disabled;
  final NeuoColors c;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: widget.c.background,
            borderRadius: 10,
            depth: _pressed ? 2 : 3,
            type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
          ),
          padding: const EdgeInsets.all(4),
          child: PopupMenuButton<String>(
            enabled: !isDisabled,  // 禁用时禁用菜单
            icon: Icon(LucideIcons.ellipsisVertical, color: widget.c.textSecondary, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onSelected: (v) {
              if (v == 'edit') context.push('/connect/${widget.printer.id}');
              if (v == 'delete') widget.onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.pencil, size: 16), SizedBox(width: 8), Text('编辑')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: Colors.red), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- 加载视图 ----
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 44,
        depth: 4,
        type: NeumorphismType.pressed,
      ),
      padding: const EdgeInsets.all(18),
      child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}

// ---- 空视图 ----
class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      FlutterNeumorphism(
        style: NeumorphismStyle(color: c.background, borderRadius: 40, depth: 7),
        padding: const EdgeInsets.all(26),
        child: Image.asset('bamboo_app_logo.png', width: 44, height: 44, fit: BoxFit.contain),
      ),
      const SizedBox(height: 22),
      Text('还没有打印机', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
      const SizedBox(height: 6),
      Text('点击右下角 ＋ 添加', style: TextStyle(fontSize: 13, color: c.textSecondary)),
    ]));
  }
}

// ---- 错误视图 ----
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.msg, required this.onRetry, required this.c});
  final String msg;
  final VoidCallback onRetry;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      FlutterNeumorphism(
        style: NeumorphismStyle(color: c.background, borderRadius: 36, depth: 5),
        padding: const EdgeInsets.all(18),
        child: const Icon(LucideIcons.triangleAlert, size: 36, color: Colors.red),
      ),
      const SizedBox(height: 14),
      Text(msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary)),
      const SizedBox(height: 18),
      _RetryButton(onPressed: onRetry, c: c),
    ])));
  }
}

// ---- 重试按钮 ----
class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
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
          borderRadius: 14,
          depth: _pressed ? 2 : 4,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.rotateCw, size: 16, color: widget.c.accent),
          const SizedBox(width: 8),
          Text('重试', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.c.accent)),
        ]),
      ),
    );
  }
}

// ---- 设备图标 ----
class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.type, required this.c});
  final PrinterType type;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final path = printerImageByType(type);
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(path, width: 42, height: 42, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _unknownIcon()),
      );
    }
    return _unknownIcon();
  }

  Widget _unknownIcon() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset('assets/printer_images/unknown.png', width: 42, height: 42, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => FlutterNeumorphism(
        style: NeumorphismStyle(color: c.background, borderRadius: 12, depth: 4, type: NeumorphismType.pressed),
        padding: const EdgeInsets.all(9),
        child: Icon(LucideIcons.printer, color: c.accent, size: 24),
      ),
    ),
  );
}