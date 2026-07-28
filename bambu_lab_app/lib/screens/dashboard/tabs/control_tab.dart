/// 高级控制 Tab（使用 flutter_neumorphism_ui）
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/ams_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

class ControlTab extends StatelessWidget {
  const ControlTab({super.key, required this.printer});
  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    final hasAms = context.watch<AmsProvider>().hasAms;

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
        SizedBox(
        height: 220,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('操作', c),
            const SizedBox(height: 8),
            Expanded(child: _Actions(printer: printer, c: c)),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('校准', c),
            const SizedBox(height: 8),
            Expanded(child: _CalibrationPanel(printer: printer, c: c)),
          ])),
        ]),
      ),
        const SizedBox(height: 14),
        _section('进退料', c),
        const SizedBox(height: 8),
        _FilamentPanel(printer: printer, hasAms: hasAms, c: c),
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
          child: _PressableButton(
            icon: l.$3,
            label: l.$1,
            selected: sel,
            onPressed: () => printer.setPrintSpeed(l.$2),
            c: c,
          ),
        ));
      }).toList()),
    );
  }
}

// ---- 可按压按钮 ----
class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.c,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
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
          depth: _pressed ? 2 : (sel ? 3 : 5),
          type: _pressed ? NeumorphismType.pressed : (sel ? NeumorphismType.pressed : NeumorphismType.flat),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 18, color: sel ? widget.c.accent : widget.c.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 4),
          Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? widget.c.accent : widget.c.textSecondary)),
        ]),
      ),
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
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 14,
        depth: 6,
      ),
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
      _ConfirmButton(onPressed: onSet, c: c),
    ]);
  }
}

// ---- 确认按钮 ----
class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
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
          borderRadius: 10,
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(LucideIcons.circleCheck, size: 18, color: widget.c.accent),
      ),
    );
  }
}

// ---- 方向键控制 + Z轴 ----
class _Actions extends StatelessWidget {
  const _Actions({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) => FlutterNeumorphism(
    style: NeumorphismStyle(
      color: c.background,
      borderRadius: 14,
      depth: 6,
    ),
    padding: const EdgeInsets.all(12),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      // XY 方向面板
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const SizedBox(width: 38),
          _DirButton(icon: LucideIcons.chevronUp, onPressed: () => printer.sendGcode('M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\nG91\nG1 Y-10.0 F3000\nM1002 pop_ref_mode\nM211 R\nG90'), c: c),
          const SizedBox(width: 38),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          _DirButton(icon: LucideIcons.chevronLeft, onPressed: () => printer.sendGcode('M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\nG91\nG1 X-10.0 F3000\nM1002 pop_ref_mode\nM211 R\nG90'), c: c),
          _HomeButton(onPressed: () => printer.autoHome(), c: c),
          _DirButton(icon: LucideIcons.chevronRight, onPressed: () => printer.sendGcode('M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\nG91\nG1 X10.0 F3000\nM1002 pop_ref_mode\nM211 R\nG90'), c: c),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const SizedBox(width: 38),
          _DirButton(icon: LucideIcons.chevronDown, onPressed: () => printer.sendGcode('M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\nG91\nG1 Y10.0 F3000\nM1002 pop_ref_mode\nM211 R\nG90'), c: c),
          const SizedBox(width: 38),
        ]),
      ]),
      const SizedBox(width: 12),
      // Z 轴
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Z轴', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 6),
        _ZButton(label: '升高', icon: LucideIcons.chevronUp, onPressed: () => printer.sendGcode('M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\nG91\nG1 Z5.0 F300\nM1002 pop_ref_mode\nM211 R\nG90'), c: c),
        const SizedBox(height: 6),
        _ZButton(label: '降低', icon: LucideIcons.chevronDown, onPressed: () => printer.sendGcode('M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\nG91\nG1 Z-5.0 F300\nM1002 pop_ref_mode\nM211 R\nG90'), c: c),
      ]),
    ]),
  );
}

// ---- 方向按钮 ----
class _DirButton extends StatefulWidget {
  const _DirButton({required this.icon, required this.onPressed, required this.c});
  final IconData icon;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_DirButton> createState() => _DirButtonState();
}

class _DirButtonState extends State<_DirButton> {
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
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(widget.icon, size: 20, color: widget.c.textPrimary),
      ),
    );
  }
}

// ---- 归零按钮 ----
class _HomeButton extends StatefulWidget {
  const _HomeButton({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<_HomeButton> {
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: widget.c.background,
            borderRadius: 12,
            depth: _pressed ? 2 : 5,
            type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(LucideIcons.home, size: 20, color: widget.c.accent),
        ),
      ),
    );
  }
}

// ---- Z轴按钮 ----
class _ZButton extends StatefulWidget {
  const _ZButton({required this.label, required this.icon, required this.onPressed, required this.c});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_ZButton> createState() => _ZButtonState();
}

class _ZButtonState extends State<_ZButton> {
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
          borderRadius: 10,
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 18, color: widget.c.accent),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.c.accent)),
        ]),
      ),
    );
  }
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
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 14,
        depth: 6,
      ),
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
          _SendButton(onPressed: () => _send(_ctrl.text), c: c),
        ]),
      ]),
    );
  }
}

// ---- 发送按钮 ----
class _SendButton extends StatefulWidget {
  const _SendButton({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
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
          borderRadius: 10,
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(LucideIcons.send, size: 18, color: widget.c.accent),
      ),
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
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 14,
        depth: 6,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _Toggle(icon: LucideIcons.layoutPanelTop, label: '热床调平', value: _bed, onChanged: (v) => setState(() => _bed = v), c: c),
        const SizedBox(height: 8),
        _Toggle(icon: LucideIcons.audioLines, label: '电机噪声', value: _motor, onChanged: (v) => setState(() => _motor = v), c: c),
        const SizedBox(height: 8),
        _Toggle(icon: LucideIcons.waves, label: '振动补偿', value: _vib, onChanged: (v) => setState(() => _vib = v), c: c),
        const SizedBox(height: 14),
        _StartButton(
          running: _running,
          onPressed: _running ? null : () async {
            setState(() => _running = true);
            await widget.printer.calibrate(bedLevel: _bed, motorNoise: _motor, vibration: _vib);
            setState(() => _running = false);
          },
          c: c,
        ),
      ]),
    );
  }
}

// ---- 开关按钮 ----
class _Toggle extends StatefulWidget {
  const _Toggle({required this.icon, required this.label, required this.value, required this.onChanged, required this.c});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final NeuoColors c;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(widget.icon, size: 16, color: widget.c.accent.withValues(alpha: 0.7)),
      const SizedBox(width: 6),
      Expanded(child: Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.c.textPrimary))),
      GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onChanged(!widget.value);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: widget.c.background,
            borderRadius: 12,
            depth: _pressed ? 2 : (widget.value ? 3 : 5),
            type: _pressed ? NeumorphismType.pressed : (widget.value ? NeumorphismType.pressed : NeumorphismType.flat),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(widget.value ? '开' : '关', style: TextStyle(fontSize: 12, fontWeight: widget.value ? FontWeight.w600 : FontWeight.w400, color: widget.value ? widget.c.accent : widget.c.textSecondary)),
        ),
      ),
    ]);
  }
}

// ---- 开始按钮 ----
class _StartButton extends StatefulWidget {
  const _StartButton({required this.running, required this.onPressed, required this.c});
  final bool running;
  final VoidCallback? onPressed;
  final NeuoColors c;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 12,
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.running ? LucideIcons.loader : LucideIcons.play, size: 18, color: widget.running ? widget.c.textSecondary.withValues(alpha: 0.5) : widget.c.accent),
          const SizedBox(width: 6),
          Text(widget.running ? '校准中...' : '开始', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.running ? widget.c.textSecondary.withValues(alpha: 0.5) : widget.c.accent)),
        ]),
      ),
    );
  }
}

class _Entry {
  final String cmd;
  final bool ok;
  const _Entry({required this.cmd, required this.ok});
}

// ---- 进退料面板 ----
class _FilamentPanel extends StatefulWidget {
  const _FilamentPanel({required this.printer, required this.hasAms, required this.c});
  final PrinterProvider printer;
  final bool hasAms;
  final NeuoColors c;

  @override
  State<_FilamentPanel> createState() => _FilamentPanelState();
}

class _FilamentPanelState extends State<_FilamentPanel> {
  int _temp = 220;
  int _length = 50;
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    if (widget.hasAms) {
      await widget.printer.loadFilament();
    } else {
      await widget.printer.manualLoadFilament(_temp, _length);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _unload() async {
    setState(() => _loading = true);
    if (widget.hasAms) {
      await widget.printer.unloadFilament();
    } else {
      await widget.printer.manualUnloadFilament(_temp, _length);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return FlutterNeumorphism(
      style: NeumorphismStyle(color: c.background, borderRadius: 14, depth: 5),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // AMS状态提示
        Row(children: [
          Icon(widget.hasAms ? LucideIcons.packageCheck : LucideIcons.packageX, size: 16,
              color: widget.hasAms ? Colors.green : c.textSecondary),
          const SizedBox(width: 6),
          Text(widget.hasAms ? 'AMS已连接 - 自动进退料' : '无AMS - 手动进退料',
              style: TextStyle(fontSize: 12, color: widget.hasAms ? Colors.green : c.textSecondary)),
        ]),
        const SizedBox(height: 12),
        // 无AMS时显示温度和长度设置
        if (!widget.hasAms) ...[
          Row(children: [
            Expanded(child: _TempInput(value: _temp, onChanged: (v) => setState(() => _temp = v), c: c)),
            const SizedBox(width: 10),
            Expanded(child: _LengthInput(value: _length, onChanged: (v) => setState(() => _length = v), c: c)),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: c.textSecondary.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
        ],
        // 进退料按钮
        if (_loading)
          const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
        else
          Row(children: [
            Expanded(child: _FilamentBtn(icon: LucideIcons.arrowDownToLine, label: '进料', color: Colors.green, onPressed: _load, c: c)),
            const SizedBox(width: 10),
            Expanded(child: _FilamentBtn(icon: LucideIcons.arrowUpFromLine, label: '退料', color: Colors.orange, onPressed: _unload, c: c)),
          ]),
      ]),
    );
  }
}

// ---- 温度输入 ----
class _TempInput extends StatefulWidget {
  const _TempInput({required this.value, required this.onChanged, required this.c});
  final int value;
  final ValueChanged<int> onChanged;
  final NeuoColors c;

  @override
  State<_TempInput> createState() => _TempInputState();
}

class _TempInputState extends State<_TempInput> {
  late final _ctrl = TextEditingController(text: widget.value.toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(LucideIcons.flame, size: 16, color: widget.c.accent),
      const SizedBox(width: 6),
      Text('温度', style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
      const SizedBox(width: 6),
      SizedBox(
        width: 60,
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: widget.c.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.c.background,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          ),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0 && n <= 300) widget.onChanged(n);
          },
        ),
      ),
      Text('°C', style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
    ]);
  }
}

// ---- 长度输入 ----
class _LengthInput extends StatefulWidget {
  const _LengthInput({required this.value, required this.onChanged, required this.c});
  final int value;
  final ValueChanged<int> onChanged;
  final NeuoColors c;

  @override
  State<_LengthInput> createState() => _LengthInputState();
}

class _LengthInputState extends State<_LengthInput> {
  late final _ctrl = TextEditingController(text: widget.value.toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(LucideIcons.ruler, size: 16, color: widget.c.accent),
      const SizedBox(width: 6),
      Text('长度', style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
      const SizedBox(width: 6),
      SizedBox(
        width: 50,
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: widget.c.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.c.background,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          ),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0 && n <= 200) widget.onChanged(n);
          },
        ),
      ),
      Text('mm', style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
    ]);
  }
}

// ---- 进退料按钮 ----
class _FilamentBtn extends StatefulWidget {
  const _FilamentBtn({required this.icon, required this.label, required this.color, required this.onPressed, required this.c});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_FilamentBtn> createState() => _FilamentBtnState();
}

class _FilamentBtnState extends State<_FilamentBtn> {
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
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, size: 18, color: widget.color),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.color)),
        ]),
      ),
    );
  }
}