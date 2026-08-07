/// WiFi 配置页面 — 扫描并连接无线网络
///
/// 通过 nmcli（NetworkManager）操作，适用于 Mobian/Phosh kiosk
/// （无系统设置入口时更换网络用）。
/// 键盘：app 全局已包 OnscreenKeyboard，输入框自动弹屏上键盘。
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bambu_lab_app/services/wifi_service.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key});

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  bool _available = true;
  bool _scanning = true;
  bool _connecting = false;
  String? _currentSsid;
  List<WifiNetwork> _networks = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _scanning = true);
    final ok = await WifiService.isAvailable();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _available = false;
        _scanning = false;
        _error = '未检测到 nmcli（NetworkManager）\n'
            '请先在系统安装：sudo apt install network-manager';
      });
      return;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    final current = await WifiService.currentSsid();
    final nets = await WifiService.scan();
    if (!mounted) return;
    setState(() {
      _currentSsid = current;
      _networks = nets;
      _scanning = false;
    });
  }

  Future<void> _connect(WifiNetwork net) async {
    if (_connecting) return;
    String? password;
    if (!net.isOpen) {
      password = await _askPassword(net.ssid);
      if (password == null) return; // 用户取消
    }
    setState(() => _connecting = true);
    final err = await WifiService.connect(net.ssid, password: password);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接到 ${net.ssid}，如打印机走 WiFi 请返回重新连接')),
      );
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFF44336)),
      );
    }
  }

  Future<String?> _askPassword(String ssid) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('连接 $ssid'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'WiFi 密码',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(controller.text),
            child: const Text('连接', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _header(c),
            const SizedBox(height: 10),
            Expanded(child: _body(c)),
          ]),
        ),
      ),
    );
  }

  Widget _header(NeuoColors c) {
    final connectedColor = const Color(0xFF4CAF50);
    return Row(children: [
      _IconButton(
        icon: LucideIcons.chevronLeft,
        onTap: _connecting ? null : () => Navigator.of(context).maybePop(),
        c: c,
      ),
      const SizedBox(width: 8),
      Text('网络设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
      const Spacer(),
      if (!_scanning)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            _currentSsid != null ? '已连接: $_currentSsid' : '未连接 WiFi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _currentSsid != null ? connectedColor : c.textSecondary,
            ),
          ),
        ),
      _IconButton(
        icon: LucideIcons.rotateCw,
        onTap: (_scanning || _connecting) ? null : _refresh,
        c: c,
      ),
    ]);
  }

  Widget _body(NeuoColors c) {
    if (!_available) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.wifiOff, size: 34, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(_error ?? '网络管理不可用',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ]),
      );
    }
    if (_scanning) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_networks.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.wifiOff, size: 34, color: c.textSecondary),
          const SizedBox(height: 12),
          Text('未扫描到 WiFi 网络', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('点击右上角刷新重试', style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _networks.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _NetworkTile(
          net: _networks[i],
          connecting: _connecting,
          c: c,
          onTap: () => _connect(_networks[i]),
        ),
      ),
    );
  }
}

/// WiFi 列表项
class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.net,
    required this.connecting,
    required this.c,
    required this.onTap,
  });

  final WifiNetwork net;
  final bool connecting;
  final NeuoColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connectedColor = const Color(0xFF4CAF50);
    final isConnected = net.connected;
    return GestureDetector(
      onTap: connecting ? null : onTap,
      child: Opacity(
        opacity: connecting ? 0.6 : 1.0,
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: c.background,
            borderRadius: 14,
            depth: isConnected ? 2 : 4,
            type: isConnected ? NeumorphismType.pressed : NeumorphismType.flat,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(
              net.isOpen ? LucideIcons.wifi : LucideIcons.lock,
              size: 20,
              color: isConnected ? connectedColor : c.accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(net.ssid,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  net.isOpen ? '开放网络' : net.security,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ]),
            ),
            _SignalBars(signal: net.signal, color: c.accent),
            const SizedBox(width: 12),
            if (isConnected)
              Text('已连接',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: connectedColor))
            else
              Icon(LucideIcons.chevronRight, size: 18, color: c.textSecondary),
          ]),
        ),
      ),
    );
  }
}

/// 信号强度指示（4 格条形）
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.signal, required this.color});

  final int signal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = (signal / 25).ceil().clamp(0, 4);
    final lowColor = signal < 30 ? const Color(0xFFF44336) : color;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 4; i++)
        Container(
          width: 3,
          height: 6.0 + i * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < active ? lowColor : Colors.grey.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ]);
  }
}

/// 拟物图标按钮（返回 / 刷新）
class _IconButton extends StatefulWidget {
  const _IconButton({required this.icon, required this.onTap, required this.c});

  final IconData icon;
  final VoidCallback? onTap;
  final NeuoColors c;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: FlutterNeumorphism(
          style: NeumorphismStyle(
            color: widget.c.background,
            borderRadius: 10,
            depth: _pressed ? 2 : 4,
            type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(widget.icon, size: 18, color: widget.c.accent),
        ),
      ),
    );
  }
}
