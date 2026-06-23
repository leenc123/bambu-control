/// 主页 - 打印机列表（紧凑拟物 v4 + Lucide）
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/printer_image.dart';
import 'package:bambu_lab_app/widgets/neuo_button.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 启动定时在线检测
    context.read<PrinterConfigProvider>().startPingLoop();
  }

  @override
  void dispose() {
    // 停止定时检测
    context.read<PrinterConfigProvider>().stopPingLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Consumer<PrinterConfigProvider>(
        builder: (_, cp, __) {
          if (cp.isLoading) return const Center(child: _LoadingView());
          if (cp.error != null) return _ErrorView(msg: cp.error!, onRetry: () => cp.loadPrinters());
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
                ),
              ),
            ),
          );
        },
      ),

        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 2, right: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(offset: Offset(3, 3), blurRadius: 10, color: Color(0x30000000)),
            BoxShadow(offset: Offset(-1, -1), blurRadius: 6, color: Color(0x40FFFFFF)),
          ],
        ),
        child: NeuoButton.fab(
          icon: const Icon(LucideIcons.plus, size: 20),
          label: const Text('添加', style: TextStyle(fontSize: 14)),
          onPressed: () => context.push('/connect'),
          accentColor: c.accent, depth: 6, intensity: 0.95,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _tap(BuildContext ctx, PrinterConfigProvider cp, PrinterConfig p) async {
    cp.selectPrinter(p);
    final pp = ctx.read<PrinterProvider>();
    // MQTT 获取到型号后自动写入数据库
    pp.onPrinterTypeDetected = (type) {
      final cfg = p.copyWith(printerType: type);
      cp.updatePrinter(cfg);
    };
    final ok = await pp.connect(p);
    if (ctx.mounted) ok ? ctx.go('/dashboard') : _err(ctx, pp.errorMessage ?? '连接失败');
  }

  Future<void> _del(BuildContext ctx, PrinterConfigProvider cp, PrinterConfig p) async {
    final ok = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
      title: const Text('确认删除'), content: Text('确定要删除打印机 "${p.name}" 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.of(c).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true && p.id != null) await cp.deletePrinter(p.id!);
  }

  void _err(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}

// ---- 打印机卡片（强拟物）----
class _PrinterTile extends StatelessWidget {
  const _PrinterTile({required this.printer, required this.isOnline, required this.onTap, required this.onDelete});
  final PrinterConfig printer;
  final bool isOnline;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return NeuoCard(
      onTap: onTap, depth: 6, intensity: 0.75, borderRadius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(children: [
        // 左侧 accent 色条 — 拟物凸起边缘
        Container(
          width: 4, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.2)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 3)],
          ),
        ),
        const SizedBox(width: 12),
        // 设备图标（优先显示型号图，未知则用图标）
        _DeviceIcon(type: printer.printerType, c: c),
        const SizedBox(width: 12),
        // 文字
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(printer.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.4), blurRadius: 3)])),
              const SizedBox(width: 4),
              Text(printer.ip, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ]),
        ),
        const SizedBox(width: 2),
        // 菜单按钮（拟物凸起）
        NeuoCard(
          shape: NeuoShape.convex, borderRadius: 10, depth: 3, intensity: 0.5,
          padding: const EdgeInsets.all(4),
          child: PopupMenuButton<String>(
            icon: Icon(LucideIcons.ellipsisVertical, color: c.textSecondary, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onSelected: (v) {
              if (v == 'edit') context.push('/connect/${printer.id}');
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Row(children: const [
                Icon(LucideIcons.pencil, size: 16), SizedBox(width: 8), Text('编辑'),
              ])),
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(LucideIcons.trash2, size: 16, color: Colors.red), SizedBox(width: 8),
                Text('删除', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => NeuoCard(
        shape: NeuoShape.concave, borderRadius: 44, depth: 4, intensity: 0.45,
        padding: const EdgeInsets.all(18),
        child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      NeuoCard(shape: NeuoShape.convex, borderRadius: 40, depth: 7, intensity: 0.7, padding: const EdgeInsets.all(26),
          child: Image.asset('bamboo_app_logo.png', width: 44, height: 44, fit: BoxFit.contain)),
      const SizedBox(height: 22),
      Text('还没有打印机', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
      const SizedBox(height: 6),
      Text('点击右下角 ＋ 添加', style: TextStyle(fontSize: 13, color: c.textSecondary)),
    ]));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      NeuoCard(shape: NeuoShape.convex, borderRadius: 36, depth: 5, intensity: 0.55, padding: const EdgeInsets.all(18),
          child: const Icon(LucideIcons.triangleAlert, size: 36, color: Colors.red)),
      const SizedBox(height: 14),
      Text(msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary)),
      const SizedBox(height: 18),
      NeuoButton(icon: const Icon(LucideIcons.rotateCw, size: 16), label: const Text('重试', style: TextStyle(fontSize: 13)),
          onPressed: onRetry, depth: 4, intensity: 0.7, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
    ])));
  }
}

// ---- 设备图标（型号图 / 凹槽图标）----
class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.type, required this.c});
  final PrinterType type; final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final path = printerImageByType(type);
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(path, width: 42, height: 42, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _unknownIcon()),
      );
    }
    return _unknownIcon();
  }

  Widget _unknownIcon() => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/printer_images/unknown.png',
            width: 42, height: 42, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => NeuoCard(
              shape: NeuoShape.concave, borderRadius: 12, depth: 4, intensity: 0.5,
              backgroundColor: c.background, padding: const EdgeInsets.all(9),
              child: Icon(LucideIcons.printer, color: c.accent, size: 24),
            )),
      );
}


