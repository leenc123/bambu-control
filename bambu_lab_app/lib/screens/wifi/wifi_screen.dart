/// WiFi 配置页面 — 扫描并连接无线网络
///
/// 通过 nmcli（NetworkManager）操作，适用于 Mobian/Phosh kiosk
/// （无系统设置入口时更换网络用）。
/// 键盘：密码输入用 OnscreenKeyboardTextFormField，弹 app 内置英文键盘
/// （flutter-pi 无物理/系统键盘，不能直接用原生 TextField）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_config_provider.dart';
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

  /// 根路由（启动流程）下监听网络就绪，一就绪自动继续
  Timer? _watchTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    super.dispose();
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
    // 启动竞态兑底：开屏判定时网络尚未就绪、加载完成时已就绪 →
    // 根路由下自动继续启动流程，不再停在配网页
    final hasNet = await WifiService.hasConnection();
    if (!mounted) return;
    final canPop = Navigator.of(context).canPop();
    debugPrint('[WIFI] 配网页加载完成 canPop=$canPop hasConnection=$hasNet');
    if (!canPop && hasNet) {
      _continueFlow();
      return;
    }
    // NM 连接慢（可能 10~30s）：挂监听，网络一就绪自动继续
    if (!canPop) {
      _watchTimer = Timer.periodic(
          const Duration(seconds: 5), (_) => _watchNetwork());
    }
  }

  /// 网络就绪监听（仅启动流程根路由；用户开始交互后自动停止）
  Future<void> _watchNetwork() async {
    if (!mounted || _connecting) return;
    if (Navigator.of(context).canPop()) {
      _watchTimer?.cancel();
      return;
    }
    final ok = await WifiService.hasConnection();
    if (!mounted) return;
    if (ok) {
      debugPrint('[WIFI] 监听：网络已就绪，继续启动流程');
      _watchTimer?.cancel();
      _continueFlow();
    }
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

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // 启动流程根路由：跳过配网继续下一步
      _continueFlow();
    }
  }

  /// 配网完成/跳过 → 继续启动流程（有设备进详情，无设备去配置）
  void _continueFlow() {
    final cp = context.read<PrinterConfigProvider>();
    context.go(cp.printers.isEmpty ? '/connect' : '/');
  }

  Future<void> _connect(WifiNetwork net) async {
    if (_connecting) return;
    // 用户开始交互：停止自动监听，避免和用户操作竞争
    _watchTimer?.cancel();
    String? password;
    if (!net.isOpen) {
      password = await _askPassword(net.ssid);
      if (password == null) return; // 用户取消
    }
    setState(() => _connecting = true);
    final err = await WifiService.connect(net.ssid, password: password);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFF44336)),
      );
      return;
    }
    // 启动配网流程（根路由、无法返回）：连网成功自动推进下一步
    if (!Navigator.of(context).canPop()) {
      _continueFlow();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已连接到 ${net.ssid}，如打印机走 WiFi 请返回重新连接')),
    );
    await _refresh();
  }

  Future<String?> _askPassword(String ssid) async {
    final controller = TextEditingController();
    final c = NeuoTheme.of(context);
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: FlutterNeumorphism(
            style: NeumorphismStyle(
              color: c.background,
              borderRadius: 18,
              depth: 8,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(LucideIcons.wifi, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('连接 $ssid',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('输入 WiFi 密码',
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 12),
                OnscreenKeyboardTextFormField(
                  controller: controller,
                  obscureText: true,
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'WiFi 密码',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: c.background,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _DialogBtn(
                        label: '取消',
                        accent: false,
                        c: c,
                        onTap: () => Navigator.of(ctx).pop()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DialogBtn(
                        label: '连接',
                        accent: true,
                        c: c,
                        onTap: () => Navigator.of(ctx).pop(controller.text)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
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
        onTap: _connecting ? null : _onBack,
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

/// 对话框按钮（拟物凸起 + 按压凹陷）
class _DialogBtn extends StatefulWidget {
  const _DialogBtn({
    required this.label,
    required this.accent,
    required this.onTap,
    required this.c,
  });

  final String label;
  final bool accent;
  final VoidCallback onTap;
  final NeuoColors c;

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
          borderRadius: 12,
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.accent ? widget.c.accent : widget.c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
