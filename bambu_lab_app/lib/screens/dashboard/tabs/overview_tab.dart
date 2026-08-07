/// 设备总览 Tab - 重新设计：预览图 + 温度 + 进度 + 控制按钮
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bambu_lab_app/models/gcode_state.dart';
import 'package:bambu_lab_app/models/print_status.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/utils/printer_image.dart';
import 'package:bambu_lab_app/widgets/ai_status_badge.dart';
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

    return Column(
      children: [
        // ---- 第一行：缩略图 + 温度（占满剩余空间）----
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: _ThumbnailCard(printer: printer, c: c)),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _TempsCard(s: s, c: c, printer: printer)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // ---- 第二行：进度 + 控制按钮（底部固定）----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _ProgressControlCard(printer: printer, c: c),
        ),
      ],
    );
  }
}

// ===== 顶部设备信息（精简）=====
class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({required this.s, required this.c});
  final dynamic s;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.wifi, size: 11, color: c.textSecondary),
        const SizedBox(width: 2),
        Text('${s.wifiSignal ?? "--"}dBm', style: TextStyle(fontSize: 10, color: c.textSecondary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: s.online ? _green.withValues(alpha: 0.15) : c.textSecondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            s.online ? '在线' : '离线',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: s.online ? _green : c.textSecondary),
          ),
        ),
      ]),
    ]);
  }
}

// ===== 缩略图卡片（左侧大图）=====
class _ThumbnailCard extends StatelessWidget {
  const _ThumbnailCard({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final image = printer.previewImage;
    final loading = printer.loadingPreview;
    final error = printer.previewError;
    final ftpOk = printer.ftpConnected;
    final isPrinting = printer.state.printStatus == PrintStatus.printing ||
        printer.state.printStatus == PrintStatus.pausedUser;

    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 14,
        depth: 5,
      ),
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        // 缩略图区域（占满剩余空间）
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: _buildThumbnail(image, loading, error, ftpOk, isPrinting),
          ),
        ),
        const SizedBox(height: 4),
        // 文件名
        SizedBox(
          width: double.infinity,
          child: Text(
            printer.state.subtaskName?.isNotEmpty == true
                ? printer.state.subtaskName!
                : (printer.state.gcodeFile?.isNotEmpty == true
                    ? printer.state.gcodeFile!
                    : '未获取到'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 10,
              color: (printer.state.subtaskName?.isNotEmpty == true ||
                      printer.state.gcodeFile?.isNotEmpty == true)
                  ? c.textSecondary
                  : c.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildThumbnail(Uint8List? image, bool loading, String? error, bool ftpOk, bool isPrinting) {
    if (image != null) {
      return GestureDetector(
        onTap: () => printer.fetchPreviewImage(),
        child: Image.memory(image, width: double.infinity, height: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/printer_images/monitor_brokenimg.png',
            width: double.infinity, height: double.infinity, fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (loading) {
      return Container(
        color: c.background.withValues(alpha: 0.5),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (error != null || !ftpOk) {
      return GestureDetector(
        onTap: () => printer.fetchPreviewImage(),
        child: Image.asset('assets/printer_images/monitor_brokenimg.png',
            width: double.infinity, height: double.infinity, fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/printer_images/monitor_sdcard_thumbnail.png',
        width: double.infinity, height: double.infinity, fit: BoxFit.cover);
  }
}

// ===== 温度卡片（右侧三行）=====
class _TempsCard extends StatelessWidget {
  const _TempsCard({required this.s, required this.c, required this.printer});
  final dynamic s;
  final NeuoColors c;
  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    // 根据打印机型号 + 灯光状态动态加载对应设备实物图，fallback 到通用示意图
    final imageAsset = printerImageByType(s.printerType, lightOn: s.lightOn) ??
        (c.background.computeLuminance() > 0.5
            ? 'assets/printer_images/devices.png'
            : 'assets/printer_images/devices-black.png');

    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 14,
        depth: 5,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备型号 + 网络状态（右对齐）
          Row(children: [
            Text(s.printerType.displayName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const Spacer(),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.wifi, size: 11, color: c.textSecondary),
              const SizedBox(width: 2),
              Text('${s.wifiSignal ?? "--"}dBm', style: TextStyle(fontSize: 10, color: c.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.online ? _green.withValues(alpha: 0.15) : c.textSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.online ? '在线' : '离线',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: s.online ? _green : c.textSecondary),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 4),
          // AI 检测服务状态（在线状态下方，右对齐，5 秒轮询）
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const AiStatusBadge(interval: Duration(seconds: 5)),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: c.background.withValues(alpha: 0.35),
                child: Stack(fit: StackFit.expand, children: [
                  // 灯光切换时跨屏淡入淡出过渡
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Center(
                      key: ValueKey(imageAsset),
                      child: Transform.scale(
                        scale: 1.15,
                        child: Image.asset(imageAsset, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  // 热床 - 底部居中，右移 10px
                  Positioned(
                    bottom: 18, left: 0, right: 0,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(10, 0),
                        child: _tempLabel(LucideIcons.grid3x3, s.bedTemp, c.accent),
                      ),
                    ),
                  ),
                  // 喷嘴 - 居中偏上 10px，左移 20px
                  Positioned.fill(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(-40, -10),
                        child: _tempLabel(LucideIcons.flame, s.nozzleTemp, _orange),
                      ),
                    ),
                  ),
                  // 箱体 - 顶部偏右（仅封闭机型显示）
                  if (s.printerType.hasChamberTemp)
                    Positioned(
                      top: 14, right: 12,
                      child: Transform.translate(
                        offset: const Offset(-60, 0),
                        child: _tempLabel(LucideIcons.home, s.chamberTemp, _green),
                      ),
                    ),
                  // 灯光开关 - 右下角
                  Positioned(
                    bottom: 12, right: 12,
                    child: GestureDetector(
                      onTap: () => printer.toggleLight(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          s.lightOn ? LucideIcons.sun : LucideIcons.lightbulb,
                          size: 16,
                          color: s.lightOn ? Colors.amber.shade300 : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tempLabel(IconData icon, double? t, Color color) {
    final textWhite = Colors.white.withValues(alpha: 0.95);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: textWhite),
        const SizedBox(width: 4),
        Text(
          t != null ? '${t.toStringAsFixed(1)}°C' : '--°C',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textWhite),
        ),
      ]),
    );
  }
}

// ===== 进度 + 控制按钮（同一卡片）=====
class _ProgressControlCard extends StatelessWidget {
  const _ProgressControlCard({required this.printer, required this.c});
  final PrinterProvider printer;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final s = printer.state;
    final pct = s.printPercentage;
    final val = (pct != null && pct > 0) ? pct / 100.0 : 0.0;
    final running = pct != null && pct > 0;

    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 14,
        depth: 5,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // 左侧：进度信息 + 进度条
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                running ? '$pct%' : '--%',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: running ? c.accent : c.textSecondary),
              ),
              const SizedBox(width: 8),
              // 显示当前阶段名（如"热床预热""首层检测"），替代固定的"打印中"
              Text(running ? s.currentStageName : '待机', style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const Spacer(),
              if (running) ...[
                Icon(LucideIcons.clock, size: 13, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(s.remainingTimeFormatted,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ],
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                width: double.infinity,
                child: Stack(children: [
                  Container(color: c.background.withValues(alpha: 0.5)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: val.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.accent, c.accent.withValues(alpha: 0.5)],
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        // 右侧：操作按钮（互斥显示）
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              // 跳过（一直显示保持布局一致）
              _ActionBtn(icon: LucideIcons.skipForward, label: '跳过',
                    color: c.textSecondary, onTap: () => printer.skipPrintObject(), c: c),
              const SizedBox(width: 10),
              // 停止（打印中或暂停时显示）
              _ActionBtn(icon: LucideIcons.square, label: '停止',
                  color: _red, onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认停止'),
                    content: const Text('确定要停止当前打印任务吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('停止', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (ok == true) await printer.stopPrint();
              }, c: c),
              const SizedBox(width: 10),
              // 暂停（打印中显示）/ 继续（暂停中显示）互斥
              if (s.printStatus.isActive)
                _ActionBtn(icon: LucideIcons.pause, label: '暂停',
                    color: _orange, onTap: () => printer.pausePrint(), c: c),
              if (s.printStatus.isPaused)
                _ActionBtn(icon: LucideIcons.play, label: '继续',
                    color: _green, onTap: () => printer.resumePrint(), c: c),
            ]),
          ],
        ),
      ]),
    );
  }
}

// ===== 单个操作按钮 =====
class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.c,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final NeuoColors c;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
          borderRadius: 10,
          depth: _pressed ? 2 : 5,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, size: 20, color: widget.color),
            const SizedBox(height: 2),
            Text(widget.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.color)),
          ]),
        ),
      ),
    );
  }
}
