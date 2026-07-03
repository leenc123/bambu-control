/// 连接编辑页（使用 flutter_neumorphism_ui）
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, this.editId});
  final int? editId;
  @override State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _accessCodeCtrl = TextEditingController();

  bool _loading = false;
  bool _isEdit = false;
  bool _useTls = true;
  bool _obscureCode = true;
  PrinterType _printerType = PrinterType.unknown;
  PrinterConfig? _existing;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.editId != null;
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    final cp = context.read<PrinterConfigProvider>();
    final p = cp.printers.firstWhere((p) => p.id == widget.editId,
        orElse: () => PrinterConfig(name: '', ip: '', serial: '', accessCode: ''));
    setState(() {
      _existing = p;
      _nameCtrl.text = p.name;
      _ipCtrl.text = p.ip;
      _serialCtrl.text = p.serial;
      _accessCodeCtrl.text = p.accessCode;
      _useTls = p.useTls;
      _printerType = p.printerType;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _serialCtrl.dispose();
    _accessCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final cp = context.read<PrinterConfigProvider>();
    final cfg = PrinterConfig(
      id: _existing?.id,
      name: _nameCtrl.text.trim(),
      ip: _ipCtrl.text.trim(),
      serial: _serialCtrl.text.trim(),
      accessCode: _accessCodeCtrl.text.trim(),
      useTls: _useTls,
      printerType: _printerType,
      lastConnected: _existing?.lastConnected,
      createdAt: _existing?.createdAt,
    );
    final ok = _isEdit ? await cp.updatePrinter(cfg) : (await cp.addPrinter(cfg)) != null;
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cp.error ?? '保存失败'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _section('基本信息', c),
            const SizedBox(height: 8),
            FlutterNeumorphism(
              style: NeumorphismStyle(color: c.background, borderRadius: 16, depth: 5),
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _field(_nameCtrl, '打印机名称', '例如：客厅打印机', c, (v) => v == null || v.trim().isEmpty ? '请输入名称' : null),
                const SizedBox(height: 12),
                _field(_ipCtrl, 'IP 地址', '192.168.1.100', c, (v) {
                  if (v == null || v.trim().isEmpty) return '请输入 IP';
                  if (!RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(v.trim())) return 'IP 格式不正确';
                  return null;
                }, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _field(_serialCtrl, '序列号', '打印机序列号', c, (v) => v == null || v.trim().isEmpty ? '请输入序列号' : null),
                const SizedBox(height: 12),
                _codeField(c),
                const SizedBox(height: 12),
                _printerTypeDropdown(c),
              ]),
            ),
            const SizedBox(height: 20),
            _section('连接选项', c),
            const SizedBox(height: 8),
            _TlsTile(useTls: _useTls, onChanged: (v) => setState(() => _useTls = v), c: c),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Row(children: [
                Expanded(child: _BackButton(onPressed: () => context.go('/'), c: c)),
                const SizedBox(width: 12),
                Expanded(child: _SaveButton(isEdit: _isEdit, onPressed: _save, c: c)),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _section(String t, NeuoColors c) => Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary));

  Widget _field(TextEditingController ctrl, String label, String hint, NeuoColors c,
      String? Function(String?)? v, {bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.4)),
          filled: true,
          fillColor: c.background,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: v,
      ),
    ]);
  }

  Widget _codeField(NeuoColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('访问码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
      const SizedBox(height: 5),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _accessCodeCtrl,
            obscureText: _obscureCode,
            style: TextStyle(fontSize: 14, color: c.textPrimary, letterSpacing: _obscureCode ? 2 : 1),
            decoration: InputDecoration(
              hintText: '打印机访问码',
              hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.4)),
              filled: true,
              fillColor: c.background,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? '请输入访问码' : null,
          ),
        ),
        const SizedBox(width: 6),
        _EyeButton(obscure: _obscureCode, onPressed: () => setState(() => _obscureCode = !_obscureCode), c: c),
      ]),
    ]);
  }

  Widget _printerTypeDropdown(NeuoColors c) {
    final types = PrinterType.values.where((t) => t != PrinterType.unknown).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('打印机型号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<PrinterType>(
            value: _printerType == PrinterType.unknown ? null : _printerType,
            hint: Text('选择打印机型号', style: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.4))),
            isExpanded: true,
            dropdownColor: c.background,
            borderRadius: BorderRadius.circular(12),
            onChanged: (v) => setState(() => _printerType = v ?? PrinterType.unknown),
            items: types.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName, style: TextStyle(fontSize: 14, color: c.textPrimary)))).toList(),
          ),
        ),
      ),
    ]);
  }
}

// ---- 显隐按钮 ----
class _EyeButton extends StatefulWidget {
  const _EyeButton({required this.obscure, required this.onPressed, required this.c});
  final bool obscure;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_EyeButton> createState() => _EyeButtonState();
}

class _EyeButtonState extends State<_EyeButton> {
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
          depth: _pressed ? 2 : 3,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.all(11),
        child: Icon(widget.obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: widget.c.textSecondary),
      ),
    );
  }
}

// ---- TLS 开关 ----
class _TlsTile extends StatefulWidget {
  const _TlsTile({required this.useTls, required this.onChanged, required this.c});
  final bool useTls;
  final ValueChanged<bool> onChanged;
  final NeuoColors c;

  @override
  State<_TlsTile> createState() => _TlsTileState();
}

class _TlsTileState extends State<_TlsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onChanged(!widget.useTls);
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TLS 加密', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.textPrimary)),
            Text(widget.useTls ? '端口 8883 — 真实打印机' : '端口 1883 — 本地测试', style: TextStyle(fontSize: 11, color: widget.c.textSecondary)),
          ])),
          Switch(value: widget.useTls, onChanged: widget.onChanged, activeTrackColor: widget.c.accent.withValues(alpha: 0.35), activeThumbColor: widget.c.accent),
        ]),
      ),
    );
  }
}

// ---- 返回按钮 ----
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
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
          depth: _pressed ? 3 : 6,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Center(child: Text('返回', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.textSecondary))),
      ),
    );
  }
}

// ---- 保存按钮 ----
class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.isEdit, required this.onPressed, required this.c});
  final bool isEdit;
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
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
          color: widget.c.accent.withValues(alpha: 0.12),
          borderRadius: 14,
          depth: _pressed ? 3 : 6,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Center(child: Text(widget.isEdit ? '保存更改' : '添加打印机', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.accent))),
      ),
    );
  }
}