/// 设备总览 Tab（现代精简风）
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/printer_image.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

const _orange = Color(0xFFF5A623);
const _green = Color(0xFF6FCF97);
const _red = Color(0xFFEB5757);

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.printer});
  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    final s = printer.state;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Header(s: s, c: c),
        const SizedBox(height: 10),
        _ProgressCard(s: s, c: c),
        const SizedBox(height: 10),
        _TempRow(s: s, c: c),
        const SizedBox(height: 10),
        _ControlCard(printer: printer),
      ],
    );
  }
}

// ===== 顶部信息 =====
class _Header extends StatelessWidget {
  const _Header({required this.s, required this.c});
  final dynamic s; final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final img = printerImageByType(s.printerType);
    return Row(children: [
      if (img != null)
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: Image.asset(img, width: 48, height: 30, fit: BoxFit.contain)),
        ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.printerType.displayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 2),
          Row(children: [
            _dot(s.online),
            const SizedBox(width: 5),
            Text(s.online ? '在线' : '离线', style: TextStyle(fontSize: 12, color: s.online ? _green : c.textSecondary)),
            const SizedBox(width: 12),
            Icon(LucideIcons.wifi, size: 12, color: c.textSecondary),
            const SizedBox(width: 3),
            Text('${s.wifiSignal ?? "--"}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(s.printStatus.displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.accent)),
      ),
    ]);
  }
}

Widget _dot(bool on) => Container(width: 7, height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: on ? _green : const Color(0xFFCCCCCC)));

// ===== 进度条 =====
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.s, required this.c});
  final dynamic s; final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final pct = s.printPercentage;
    final val = (pct != null && pct > 0) ? pct / 100.0 : 0.0;
    final running = pct != null && pct > 0;

    return NeuoCard(borderRadius: 14, depth: 4, intensity: 0.6, padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Text('打印进度', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary)),
          const Spacer(),
          if (running) ...[
            Icon(LucideIcons.clock, size: 12, color: c.textSecondary), const SizedBox(width: 4),
            Text(s.remainingTimeFormatted, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
            const SizedBox(width: 10),
          ],
          Text(running ? '${pct!}%' : '--', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: running ? c.accent : c.textSecondary)),
        ]),
        const SizedBox(height: 10),
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Stack(children: [
              // 底轨
              Container(color: c.background.withValues(alpha: 0.5)),
              // 填充段
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: val.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.5)], end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(width: 8, decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ===== 温度行 =====
class _TempRow extends StatelessWidget {
  const _TempRow({required this.s, required this.c});
  final dynamic s; final NeuoColors c;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _temp('热床', s.bedTemp, LucideIcons.grid3x3, c.accent, c)),
    const SizedBox(width: 8),
    Expanded(child: _temp('喷嘴', s.nozzleTemp, LucideIcons.flame, _orange, c)),
    if (s.chamberTemp != null) ...[const SizedBox(width: 8), Expanded(child: _temp('箱体', s.chamberTemp, LucideIcons.home, _green, c))],
  ]);

  Widget _temp(String label, double? t, IconData icon, Color color, NeuoColors c) => NeuoCard(
        borderRadius: 12, depth: 3, intensity: 0.5, padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary))]),
          const SizedBox(height: 6),
          Text(t != null ? '${t.toStringAsFixed(1)}°C' : '--°C', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

// ===== 控制卡 =====
class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.printer});
  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return NeuoCard(borderRadius: 14, depth: 4, intensity: 0.6, padding: const EdgeInsets.all(14),
      child: Column(children: [
        // 按钮行
        Row(children: [
          Expanded(child: _ctrlBtn('暂停', LucideIcons.pause, _orange, () => printer.pausePrint(), c)),
          const SizedBox(width: 6),
          Expanded(child: _ctrlBtn('继续', LucideIcons.play, _green, () => printer.resumePrint(), c)),
          const SizedBox(width: 6),
          Expanded(child: _ctrlBtn('停止', LucideIcons.square, _red, () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('确认停止'), content: const Text('确定要停止当前打印任务吗？'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('停止', style: TextStyle(color: Colors.red))),
              ],
            ));
            if (ok == true) await printer.stopPrint();
          }, c)),
        ]),
        const SizedBox(height: 14),
        // 分隔
        Container(height: 1, color: c.textSecondary.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        // 风扇
        _FanDisplay(printer: printer, c: c),
        const SizedBox(height: 12),
        Container(height: 1, color: c.textSecondary.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        // 灯光
        _LightRow(printer: printer, c: c),
      ]),
    );
  }

  Widget _ctrlBtn(String label, IconData icon, Color color, VoidCallback? onTap, NeuoColors c) {
    return NeuoCard(
      onTap: onTap,
      depth: 3, intensity: 0.5, borderRadius: 12,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ===== 风扇显示（只读）=====
class _FanDisplay extends StatelessWidget {
  const _FanDisplay({required this.printer, required this.c});
  final PrinterProvider printer; final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final p = (printer.state.fanSpeed ?? 0).toInt();
    final a = (printer.state.auxFanSpeed ?? 0).toInt();
    return Row(children: [
      Expanded(child: _bar(LucideIcons.fan, '模型风扇', p, c.accent, c)),
      const SizedBox(width: 12),
      Expanded(child: _bar(LucideIcons.wind, '辅助风扇', a, c.accent, c)),
    ]);
  }

  Widget _bar(IconData icon, String label, int val, Color ac, NeuoColors c) {
    final pct = (val / 100).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: c.textSecondary), const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textPrimary)),
        const Spacer(),
        Text('$val%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ac)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: SizedBox(height: 8, child: Stack(children: [
          Container(color: c.background.withValues(alpha: 0.5)),
          FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct,
            child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(colors: [ac, ac.withValues(alpha: 0.4)], end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(4),
            ))),
        ])),
      ),
    ]);
  }
}

// ===== 灯光 =====
class _LightRow extends StatelessWidget {
  const _LightRow({required this.printer, required this.c});
  final PrinterProvider printer; final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final on = printer.state.lightOn;
    return Row(children: [
      Icon(LucideIcons.lightbulb, size: 14, color: on ? Colors.amber : c.textSecondary),
      const SizedBox(width: 6),
      Text('灯光', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textPrimary)),
      const Spacer(),
      NeuoCard(
        onTap: () => printer.toggleLight(),
        borderRadius: 8, depth: on ? 2 : 3, intensity: on ? 0.4 : 0.5,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(on ? '开' : '关', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.amber : c.textSecondary)),
      ),
    ]);
  }
}
