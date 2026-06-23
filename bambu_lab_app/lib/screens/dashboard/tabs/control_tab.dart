/// 高级控制 Tab（使用自定义拟物组件）
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';
import 'package:bambu_lab_app/widgets/neuo_button.dart';

class ControlTab extends StatelessWidget {
  const ControlTab({super.key, required this.printer});
  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _section('打印速度', c),
        const SizedBox(height: 8),
        _SpeedPicker(printer: printer, c: c),
        const SizedBox(height: 14),
        _section('温度设置', c),
        const SizedBox(height: 8),
        _TempInputs(printer: printer, c: c),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('操作', c),
            const SizedBox(height: 8),
            _Actions(printer: printer, c: c),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('校准', c),
            const SizedBox(height: 8),
            _CalibrationPanel(printer: printer, c: c),
          ])),
        ]),
        const SizedBox(height: 14),
        _section('G-code 终端', c),
        const SizedBox(height: 8),
        _GcodeTerminal(printer: printer, c: c),
      ],
    );
  }

  Widget _section(String t, NeuoColors c) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
  );
}

// ---- 速度选择 ----
class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;

  static const _levels = [
    ('静音', 1, LucideIcons.moon),
    ('标准', 2, LucideIcons.gauge),
    ('运动', 3, LucideIcons.zap),
    ('狂暴', 4, LucideIcons.bolt),
  ];

  @override
  Widget build(BuildContext context) {
    final cur = printer.state.printSpeed;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(children: _levels.map((l) {
        final sel = cur == l.$2;
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: NeuoButton(
            icon: Icon(l.$3, size: 18),
            label: Text(l.$1, style: TextStyle(fontSize: 12)),
            borderRadius: 10,
            depth: sel ? 3 : 5,
            intensity: sel ? 0.6 : 0.8,
            backgroundColor: sel ? c.accent.withValues(alpha: 0.15) : null,
            accentColor: sel ? c.accent : null,
            onPressed: () => printer.setPrintSpeed(l.$2),
          ),
        ));
      }).toList()),
    );
  }
}

// ---- 温度输入 ----
class _TempInputs extends StatefulWidget {
  const _TempInputs({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;
  @override
  State<_TempInputs> createState() => _TempInputsState();
}

class _TempInputsState extends State<_TempInputs> {
  final _bedCtrl = TextEditingController();
  final _nozCtrl = TextEditingController();

  @override
  void dispose() {
    _bedCtrl.dispose();
    _nozCtrl.dispose();
    super.dispose();
  }

  Future<void> _setTemp(TextEditingController ctrl, Future<void> Function(int) fn) async {
    final v = int.tryParse(ctrl.text.trim());
    if (v != null && v > 0) {
      await fn(v);
      ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return NeuoCard(
      borderRadius: 14,
      depth: 4,
      intensity: 0.6,
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _tempRow('热床温度', LucideIcons.grid3x3, _bedCtrl, '60', c, () => _setTemp(_bedCtrl, widget.printer.setBedTemperature)),
        const SizedBox(height: 8),
        Container(height: 1, color: c.textSecondary.withValues(alpha: 0.1)),
        const SizedBox(height: 8),
        _tempRow('喷嘴温度', LucideIcons.flame, _nozCtrl, '220', c, () => _setTemp(_nozCtrl, widget.printer.setNozzleTemperature)),
      ]),
    );
  }

  Widget _tempRow(String label, IconData icon, TextEditingController ctrl, String hint, NeuoColors c, VoidCallback onSet) {
    return Row(children: [
      Icon(icon, color: c.accent, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textPrimary))),
      SizedBox(
        width: 64,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.4)),
            filled: true,
            fillColor: c.background,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Text('°C', style: TextStyle(fontSize: 12, color: c.textSecondary)),
      const SizedBox(width: 4),
      NeuoButton.icon(
        icon: Icon(LucideIcons.circleCheck, size: 18),
        borderRadius: 10,
        padding: const EdgeInsets.all(8),
        accentColor: c.accent,
        onPressed: onSet,
      ),
    ]);
  }
}

// ---- 方向键控制 + Z轴 ----
class _Actions extends StatelessWidget {
  const _Actions({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) => NeuoCard(
    borderRadius: 14,
    depth: 4,
    intensity: 0.6,
    padding: const EdgeInsets.all(12),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      // XY 方向面板
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const SizedBox(width: 38),
          NeuoButton.icon(
            icon: Icon(LucideIcons.chevronUp, size: 20),
            borderRadius: 12,
            padding: const EdgeInsets.all(10),
            onPressed: () => printer.sendGcode('G91\nG1 Y-10 F3000\nG90'),
          ),
          const SizedBox(width: 38),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          NeuoButton.icon(
            icon: Icon(LucideIcons.chevronLeft, size: 20),
            borderRadius: 12,
            padding: const EdgeInsets.all(10),
            onPressed: () => printer.sendGcode('G91\nG1 X-10 F3000\nG90'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: NeuoButton.fab(
              icon: Icon(LucideIcons.home, size: 20),
              borderRadius: 12,
              padding: const EdgeInsets.all(10),
              accentColor: c.accent,
              onPressed: () => printer.autoHome(),
            ),
          ),
          NeuoButton.icon(
            icon: Icon(LucideIcons.chevronRight, size: 20),
            borderRadius: 12,
            padding: const EdgeInsets.all(10),
            onPressed: () => printer.sendGcode('G91\nG1 X10 F3000\nG90'),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const SizedBox(width: 38),
          NeuoButton.icon(
            icon: Icon(LucideIcons.chevronDown, size: 20),
            borderRadius: 12,
            padding: const EdgeInsets.all(10),
            onPressed: () => printer.sendGcode('G91\nG1 Y10 F3000\nG90'),
          ),
          const SizedBox(width: 38),
        ]),
      ]),
      const SizedBox(width: 12),
      // Z 轴
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Z轴', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 6),
        NeuoButton(
          icon: Icon(LucideIcons.chevronUp, size: 18),
          label: Text('升高', style: TextStyle(fontSize: 12)),
          borderRadius: 10,
          depth: 4,
          intensity: 0.7,
          accentColor: c.accent,
          onPressed: () => printer.sendGcode('G91\nG1 Z5 F300\nG90'),
        ),
        const SizedBox(height: 6),
        NeuoButton(
          icon: Icon(LucideIcons.chevronDown, size: 18),
          label: Text('降低', style: TextStyle(fontSize: 12)),
          borderRadius: 10,
          depth: 4,
          intensity: 0.7,
          accentColor: c.accent,
          onPressed: () => printer.sendGcode('G91\nG1 Z-5 F300\nG90'),
        ),
      ]),
    ]),
  );
}

// ---- G-code ----
class _GcodeTerminal extends StatefulWidget {
  const _GcodeTerminal({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;
  @override
  State<_GcodeTerminal> createState() => _GcodeTerminalState();
}

class _GcodeTerminalState extends State<_GcodeTerminal> {
  final _ctrl = TextEditingController();
  final _history = <_Entry>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send(String cmd) async {
    final t = cmd.trim();
    if (t.isEmpty) return;
    final ok = await widget.printer.sendGcode(t);
    setState(() => _history.add(_Entry(cmd: t, ok: ok)));
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return NeuoCard(
      borderRadius: 14,
      depth: 4,
      intensity: 0.6,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        if (_history.isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(8)),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(6),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final e = _history[i];
                return Text('> ${e.cmd}', style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: e.ok ? c.textPrimary : Colors.red,
                ));
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: '输入 G-code (如 G28)',
                hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.4), fontSize: 12),
                filled: true,
                fillColor: c.background,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 6),
          NeuoButton.icon(
            icon: Icon(LucideIcons.send, size: 18),
            borderRadius: 10,
            padding: const EdgeInsets.all(8),
            accentColor: c.accent,
            onPressed: () => _send(_ctrl.text),
          ),
        ]),
      ]),
    );
  }
}

// ---- 校准面板 ----
class _CalibrationPanel extends StatefulWidget {
  const _CalibrationPanel({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;
  @override
  State<_CalibrationPanel> createState() => _CalibrationPanelState();
}

class _CalibrationPanelState extends State<_CalibrationPanel> {
  bool _bed = true, _motor = true, _vib = true;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return NeuoCard(
      borderRadius: 14,
      depth: 4,
      intensity: 0.6,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _toggle('热床调平', _bed, (v) => setState(() => _bed = v), c),
        const SizedBox(height: 8),
        _toggle('电机噪声', _motor, (v) => setState(() => _motor = v), c),
        const SizedBox(height: 8),
        _toggle('振动补偿', _vib, (v) => setState(() => _vib = v), c),
        const SizedBox(height: 14),
        NeuoButton.fab(
          icon: _running ? Icon(LucideIcons.loader, size: 18) : Icon(LucideIcons.play, size: 18),
          label: Text(_running ? '校准中...' : '开始', style: TextStyle(fontSize: 12)),
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          accentColor: _running ? c.textSecondary : c.accent,
          onPressed: _running ? null : () async {
            setState(() => _running = true);
            await widget.printer.calibrate(bedLevel: _bed, motorNoise: _motor, vibration: _vib);
            setState(() => _running = false);
          },
        ),
      ]),
    );
  }

  Widget _toggle(String label, bool val, ValueChanged<bool> onChanged, NeuoColors c) {
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textPrimary))),
      NeuoButton(
        label: Text(val ? '开' : '关', style: TextStyle(fontSize: 12)),
        borderRadius: 8,
        depth: val ? 3 : 5,
        intensity: val ? 0.6 : 0.8,
        backgroundColor: val ? c.accent.withValues(alpha: 0.15) : null,
        accentColor: val ? c.accent : null,
        onPressed: () => onChanged(!val),
      ),
    ]);
  }
}

class _Entry {
  final String cmd;
  final bool ok;
  const _Entry({required this.cmd, required this.ok});
}