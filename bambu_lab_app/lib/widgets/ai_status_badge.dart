/// 紧凑版 AI 检测服务状态徽标：圆点 + 短文本，定时探测推理服务。
///
/// 用于总览页缩略图卡片等需要"常驻但低调"展示服务可用性的位置。
/// 默认每 30 秒探测一次，可通过 [interval] 调整（如总览页用 5 秒）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bambu_lab_app/services/ai_service.dart';

enum _BadgeStatus { checking, available, unavailable }

class AiStatusBadge extends StatefulWidget {
  const AiStatusBadge({super.key, this.interval = const Duration(seconds: 30)});

  /// 健康检查轮询间隔。
  final Duration interval;

  @override
  State<AiStatusBadge> createState() => _AiStatusBadgeState();
}

class _AiStatusBadgeState extends State<AiStatusBadge> {
  _BadgeStatus _status = _BadgeStatus.checking;
  bool _probed = false;  // 是否完成过首次探测（未探测前显示"检测中"）
  bool _probing = false; // 并发守卫：一次只允许一个探测在途
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(widget.interval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_probing) return;
    _probing = true;
    final (ok, _, _) = await probeAiService();
    _probing = false;
    if (!mounted) return;
    setState(() {
      _status = ok ? _BadgeStatus.available : _BadgeStatus.unavailable;
      _probed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    // 未完成首次探测前显示"检测中"；之后只显示可用/不可用（重探静默）
    if (!_probed) {
      color = Colors.grey;
      text = 'AI: 检测中';
    } else {
      switch (_status) {
        case _BadgeStatus.available:
          color = const Color(0xFF4CAF50);
          text = 'AI: 可用';
          break;
        case _BadgeStatus.unavailable:
          color = const Color(0xFFF44336);
          text = 'AI: 不可用';
          break;
        default:
          color = Colors.grey;
          text = 'AI: 检测中';
          break;
      }
    }

    // 胶囊徽标：淡色底 + 图标 + 文本（与"在线"徽章风格一致）
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.cpu, size: 11, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            )),
      ]),
    );
  }
}
