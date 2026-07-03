/// AMS 耗材管理 Tab（使用 flutter_neumorphism_ui）
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/ams.dart';
import 'package:bambu_lab_app/models/filament.dart';
import 'package:bambu_lab_app/models/filament_tray.dart';
import 'package:bambu_lab_app/providers/ams_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

class AmsTab extends StatelessWidget {
  const AmsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Consumer<AmsProvider>(
      builder: (_, ams, __) {
        if (!ams.hasAms) return _NoAms(c: c);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final e in ams.hub.amsHub.entries) ...[
              _UnitCard(index: e.key, ams: e.value, c: c),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

// ---- AMS 单元卡片 ----
class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.index, required this.ams, required this.c});
  final int index; final AMS ams; final NeuoColors c;

  Color _hclr(int h) {
    if (h <= 20) return Colors.green;
    if (h <= 40) return Colors.blue;
    if (h <= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final hclr = _hclr(ams.humidity);
    return FlutterNeumorphism(
      style: NeumorphismStyle(color: c.background, borderRadius: 14, depth: 5),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 标题
        Row(children: [
          Icon(LucideIcons.packageOpen, color: c.accent, size: 20),
          const SizedBox(width: 6),
          Text('AMS #${index + 1}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const Spacer(),
          _chip(LucideIcons.droplets, '${ams.humidity}%', hclr, c),
          const SizedBox(width: 6),
          _chip(LucideIcons.thermometer, '${ams.temperature.toStringAsFixed(1)}°C', Colors.orange, c),
        ]),
        const SizedBox(height: 10),
        // 料盘 - 显示所有4个槽位,未识别的显示占位符
        if (ams.filamentTrays.isEmpty)
          Text('无耗材信息', style: TextStyle(fontSize: 12, color: c.textSecondary))
        else
          ...List.generate(4, (slotIndex) {
            final tray = ams.filamentTrays[slotIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: tray != null && tray.isValid
                  ? _TrayCard(slot: slotIndex, tray: tray, c: c)
                  : _EmptySlotCard(slot: slotIndex, c: c),
            );
          }),
      ]),
    );
  }

  Widget _chip(IconData icon, String text, Color color, NeuoColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// ---- 单个料盘（可点击编辑）----
class _TrayCard extends StatefulWidget {
  const _TrayCard({required this.slot, required this.tray, required this.c});
  final int slot; final FilamentTray tray; final NeuoColors c;

  @override
  State<_TrayCard> createState() => _TrayCardState();
}

class _TrayCardState extends State<_TrayCard> {
  bool _pressed = false;

  Color? _parse(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } on FormatException {/* ignore */}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final clr = _parse(widget.tray.displayColor);
    final has = widget.tray.isValid;  // 使用isValid判断数据完整性

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _editDialog(context, widget.slot, widget.tray, widget.c);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 10,
          depth: _pressed ? 2 : 3,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              color: has ? (clr ?? widget.c.textSecondary) : widget.c.background,
              shape: BoxShape.circle,
              border: Border.all(color: widget.c.textSecondary.withValues(alpha: 0.2), width: 2),
              boxShadow: has ? [BoxShadow(color: (clr ?? widget.c.textSecondary).withValues(alpha: 0.4), blurRadius: 4)] : [],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#${widget.slot + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.c.accent)),
              if (has) ...[const SizedBox(width: 6), Text(widget.tray.trayType,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.c.textPrimary))],
            ]),
            if (widget.tray.traySubBrands.isNotEmpty)
              Text(widget.tray.traySubBrands, style: TextStyle(fontSize: 11, color: widget.c.textSecondary), overflow: TextOverflow.ellipsis),
          ])),
          if (widget.tray.nozzleTempMax > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('${widget.tray.nozzleTempMin}-${widget.tray.nozzleTempMax}°C', style: TextStyle(fontSize: 11, color: widget.c.textSecondary)),
            ),
          const SizedBox(width: 4),
          Icon(LucideIcons.pencil, size: 14, color: widget.c.accent.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  // ---- 编辑弹窗（材料 + 颜色）----
  Future<void> _editDialog(BuildContext ctx, int slot, FilamentTray tray, NeuoColors c) async {
    final printer = ctx.read<PrinterProvider>().service;
    if (printer == null) return;

    // 第一步：选材料
    final material = await showDialog<Filament>(
      context: ctx,
      builder: (ctx) => _MaterialPicker(c: c),
    );
    if (material == null || !ctx.mounted) return;

    // 第二步：选颜色
    final colorHex = await showDialog<String>(
      context: ctx,
      builder: (ctx) => _ColorPicker(c: c, currentColor: tray.displayColor),
    );
    if (colorHex == null || !ctx.mounted) return;

    // 发送到打印机
    await printer.setPrinterFilament(
      filament: material.settings,
      color: colorHex,
      amsId: slot == 0 ? 255 : slot,
      trayId: slot == 0 ? 254 : slot,
    );
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('已发送: #${slot + 1} → ${material.displayName}'),
            backgroundColor: const Color(0xFF6FCF97), duration: const Duration(seconds: 2)),
      );
    }
  }
}

// ---- 空槽位占位符 ----
class _EmptySlotCard extends StatelessWidget {
  const _EmptySlotCard({required this.slot, required this.c});
  final int slot; final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 10,
        depth: 3,
        type: NeumorphismType.flat,
      ),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: c.background,
            shape: BoxShape.circle,
            border: Border.all(color: c.textSecondary.withValues(alpha: 0.15), width: 2),
          ),
          child: Icon(LucideIcons.circleDashed, size: 16, color: c.textSecondary.withValues(alpha: 0.3)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('#${slot + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
            const SizedBox(width: 6),
            Text('空槽位', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary)),
          ]),
          Text('未识别到耗材', style: TextStyle(fontSize: 11, color: c.textSecondary.withValues(alpha: 0.6))),
        ])),
      ]),
    );
  }
}

// ---- 材料选择弹窗 ----
class _MaterialPicker extends StatelessWidget {
  const _MaterialPicker({required this.c});
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final types = Filament.values;
    return AlertDialog(
      backgroundColor: c.background,
      title: const Text('选择耗材类型'),
      content: SizedBox(
        width: 320,
        height: 300,
        child: ListView.builder(
          itemCount: types.length,
          itemBuilder: (_, i) {
            final f = types[i];
            return ListTile(
              dense: true,
              title: Text(f.displayName, style: TextStyle(fontSize: 13, color: c.textPrimary)),
              subtitle: Text('${f.trayType}  ${f.nozzleTempMin}-${f.nozzleTempMax}°C',
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
              onTap: () => Navigator.of(context).pop(f),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('取消')),
      ],
    );
  }
}

// ---- 颜色选择器 ----
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.c, required this.currentColor});
  final NeuoColors c; final String currentColor;

  static const _colors = [
    ('FF5733', '橙红'), ('E84D39', '红'), ('FF6B9D', '粉'),
    ('9B59B6', '紫'), ('3498DB', '蓝'), ('2ECC71', '绿'),
    ('1ABC9C', '青'), ('F1C40F', '黄'), ('E67E22', '橙'),
    ('95A5A6', '灰'), ('34495E', '深灰'), ('FFFFFF', '白'),
    ('ECF0F1', '浅灰'), ('000000', '黑'), ('8E44AD', '深紫'),
    ('2980B9', '深蓝'), ('27AE60', '深绿'), ('D35400', '棕'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: c.background,
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8, runSpacing: 8,
          children: _colors.map((e) {
            final hex = e.$1;
            final name = e.$2;
            final isCurrent = hex == currentColor.replaceAll('#', '');
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(hex),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Color(int.parse('FF$hex', radix: 16)),
                    shape: BoxShape.circle,
                    border: Border.all(color: isCurrent ? c.accent : c.textSecondary.withValues(alpha: 0.3), width: isCurrent ? 3 : 1.5),
                    boxShadow: isCurrent ? [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 6)] : [],
                  ),
                ),
                const SizedBox(height: 2),
                Text(name, style: TextStyle(fontSize: 9, color: c.textSecondary)),
              ]),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('取消')),
      ],
    );
  }
}

// ---- 无 AMS ----
class _NoAms extends StatelessWidget {
  const _NoAms({required this.c});
  final NeuoColors c;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FlutterNeumorphism(
            style: NeumorphismStyle(color: c.background, borderRadius: 40, depth: 5),
            padding: const EdgeInsets.all(24),
            child: Icon(LucideIcons.packageOpen, size: 48, color: c.textSecondary.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 18),
          Text('未检测到 AMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('请确保 AMS 已连接打印机', style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ]),
      );
}