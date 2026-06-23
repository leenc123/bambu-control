/// 连接编辑页（紧凑拟物 + 访问码显隐）
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/widgets/neuo_button.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

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
      _existing = p; _nameCtrl.text = p.name; _ipCtrl.text = p.ip;
      _serialCtrl.text = p.serial; _accessCodeCtrl.text = p.accessCode;
      _useTls = p.useTls; _printerType = p.printerType;
    });
  }

  @override void dispose() {
    _nameCtrl.dispose(); _ipCtrl.dispose(); _serialCtrl.dispose(); _accessCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final cp = context.read<PrinterConfigProvider>();
    final cfg = PrinterConfig(
      id: _existing?.id, name: _nameCtrl.text.trim(), ip: _ipCtrl.text.trim(),
      serial: _serialCtrl.text.trim(), accessCode: _accessCodeCtrl.text.trim(),
      useTls: _useTls, printerType: _printerType,
      lastConnected: _existing?.lastConnected, createdAt: _existing?.createdAt,
    );
    final ok = _isEdit ? await cp.updatePrinter(cfg) : (await cp.addPrinter(cfg)) != null;
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) { context.go('/'); }
    else { ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cp.error ?? '保存失败'), backgroundColor: Colors.red)); }
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
            _section('基本信息', c), const SizedBox(height: 8),
            NeuoCard(depth: 5, intensity: 0.6, borderRadius: 16, padding: const EdgeInsets.all(14),
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
            _section('连接选项', c), const SizedBox(height: 8),
            _tlsTile(c),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator())
            else Row(children: [
              Expanded(child: NeuoButton(
                label: const Text('返回', style: TextStyle(fontSize: 14)),
                onPressed: () => context.go('/'), depth: 6, intensity: 0.7,
                padding: const EdgeInsets.symmetric(vertical: 13),
              )),
              const SizedBox(width: 12),
              Expanded(child: NeuoButton(
                label: Text(_isEdit ? '保存更改' : '添加打印机', style: const TextStyle(fontSize: 14, color: Colors.white)),
                onPressed: _save, accentColor: c.accent, depth: 7, intensity: 0.9,
                padding: const EdgeInsets.symmetric(vertical: 13),
              )),
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
        controller: ctrl, obscureText: obscure, keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.4)),
          filled: true, fillColor: c.background, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: v,
      ),
    ]);
  }

  // ---- 访问码（带显隐按钮）----
  Widget _codeField(NeuoColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('访问码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
      const SizedBox(height: 5),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _accessCodeCtrl, obscureText: _obscureCode,
            style: TextStyle(fontSize: 14, color: c.textPrimary, letterSpacing: _obscureCode ? 2 : 1),
            decoration: InputDecoration(
              hintText: '打印机访问码', hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.4)),
              filled: true, fillColor: c.background, isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? '请输入访问码' : null,
          ),
        ),
        const SizedBox(width: 6),
        NeuoButton.icon(
          icon: Icon(_obscureCode ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
          onPressed: () => setState(() => _obscureCode = !_obscureCode),
          depth: 3, intensity: 0.5, padding: const EdgeInsets.all(11),
        ),
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
            isExpanded: true, dropdownColor: c.background, borderRadius: BorderRadius.circular(12),
            onChanged: (v) => setState(() => _printerType = v ?? PrinterType.unknown),
            items: types.map((t) => DropdownMenuItem(value: t,
                child: Text(t.displayName, style: TextStyle(fontSize: 14, color: c.textPrimary)))).toList(),
          ),
        ),
      ),
    ]);
  }

  Widget _tlsTile(NeuoColors c) => NeuoCard(
        onTap: () => setState(() => _useTls = !_useTls),
        depth: 5, intensity: 0.65, borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TLS 加密', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            Text(_useTls ? '端口 8883 — 真实打印机' : '端口 1883 — 本地测试', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ])),
          Switch(value: _useTls, onChanged: (v) => setState(() => _useTls = v),
              activeTrackColor: c.accent.withValues(alpha: 0.35), activeThumbColor: c.accent),
        ]),
      );
}
