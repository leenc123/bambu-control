/// AI 检测 Tab — 检测配置 + 检测记录
///
/// 服务可用性由总览页徽标展示（5 秒轮询），本页不再展示状态卡片；
/// 仅当推理服务可用时才允许配置（不可用则整块禁用）。
/// 配置随打印机持久化到数据库。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/providers/ai_monitor_provider.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/services/ai_service.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/widgets/neo_toggle.dart';

enum _AiStatus { checking, available, unavailable }

const _red = Color(0xFFF44336);

class AiTab extends StatefulWidget {
  const AiTab({super.key});

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  _AiStatus _status = _AiStatus.checking;
  bool _probing = false; // 并发守卫：一次只允许一个探测在途
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    // 30 秒重探：服务恢复/挂掉时自动启用/禁用配置
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
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
    setState(() =>
        _status = ok ? _AiStatus.available : _AiStatus.unavailable);
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    final cfg = context.watch<PrinterConfigProvider>().selected;
    final monitor = context.watch<AiMonitorProvider>();
    // 探测中按可用处理（避免页面刚打开时配置闪一下禁用）；
    // 确认不可用后整块禁用。
    final available = _status != _AiStatus.unavailable;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!available) ...[
            Row(children: [
              Icon(LucideIcons.alertTriangle, size: 13, color: _red),
              const SizedBox(width: 6),
              Text('AI 检测服务不可用，配置已禁用',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _red)),
            ]),
            const SizedBox(height: 8),
          ],
          if (cfg != null)
            Opacity(
              opacity: available ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !available,
                child: _ConfigCard(
                  cfg: cfg,
                  c: c,
                  onChanged: (updated) =>
                      context.read<PrinterConfigProvider>().updatePrinter(updated),
                ),
              ),
            ),
          _InspectionSection(c: c, monitor: monitor),
        ],
      ),
    );
  }
}

/// 检测配置卡片（阈值 / 最大连续检出 / 自动暂停）
class _ConfigCard extends StatefulWidget {
  const _ConfigCard({required this.cfg, required this.c, required this.onChanged});
  final PrinterConfig cfg;
  final NeuoColors c;
  final ValueChanged<PrinterConfig> onChanged;

  @override
  State<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<_ConfigCard> {
  late double _threshold;
  late int _maxConsecutive;
  late bool _autoPause;

  @override
  void initState() {
    super.initState();
    _threshold = widget.cfg.aiConfidenceThreshold;
    _maxConsecutive = widget.cfg.aiMaxConsecutive;
    _autoPause = widget.cfg.aiAutoPause;
  }

  void _save() {
    widget.onChanged(widget.cfg.copyWith(
      aiConfidenceThreshold: _threshold,
      aiMaxConsecutive: _maxConsecutive,
      aiAutoPause: _autoPause,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 16,
        depth: 5,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('检测配置',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('连续检出超过上限即判定打印缺陷，可自动暂停打印',
              style: TextStyle(fontSize: 11, color: c.textSecondary)),
          const SizedBox(height: 12),
          // ---- 检测阈值 ----
          Row(children: [
            Expanded(
              child: Text('检测阈值',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
            Text(_threshold.toStringAsFixed(2),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
          ]),
          Slider(
            value: _threshold,
            min: 0.1,
            max: 0.9,
            divisions: 16,
            activeColor: c.accent,
            onChanged: (v) => setState(() => _threshold = v),
            onChangeEnd: (_) => _save(),
          ),
          const SizedBox(height: 4),
          // ---- 最大连续检出次数 ----
          Row(children: [
            Expanded(
              child: Text('最大连续检出次数',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
            _StepperBtn(
              icon: LucideIcons.minus,
              c: c,
              onTap: () {
                if (_maxConsecutive > 1) {
                  setState(() => _maxConsecutive--);
                  _save();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('$_maxConsecutive',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
            ),
            _StepperBtn(
              icon: LucideIcons.plus,
              c: c,
              onTap: () {
                if (_maxConsecutive < 10) {
                  setState(() => _maxConsecutive++);
                  _save();
                }
              },
            ),
          ]),
          const SizedBox(height: 14),
          // ---- 自动暂停 ----
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('自动暂停打印',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                Text('判定缺陷后自动暂停，避免继续损坏',
                    style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ]),
            ),
            // 拟物开关（与校准面板一致）
            NeoToggle(
              value: _autoPause,
              c: c,
              onChanged: (v) {
                setState(() => _autoPause = v);
                _save();
              },
            ),
          ]),
        ],
      ),
    );
  }
}

/// 步进按钮（- / +）
class _StepperBtn extends StatefulWidget {
  const _StepperBtn({required this.icon, required this.c, required this.onTap});
  final IconData icon;
  final NeuoColors c;
  final VoidCallback onTap;

  @override
  State<_StepperBtn> createState() => _StepperBtnState();
}

class _StepperBtnState extends State<_StepperBtn> {
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
          borderRadius: 8,
          depth: _pressed ? 2 : 4,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(widget.icon, size: 14, color: widget.c.accent),
      ),
    );
  }
}

/// 检测记录区：打印中每分钟自动检测的结果（送检图 + 标注图 + 结果）
class _InspectionSection extends StatelessWidget {
  const _InspectionSection({required this.c, required this.monitor});

  final NeuoColors c;
  final AiMonitorProvider monitor;

  @override
  Widget build(BuildContext context) {
    final records = monitor.records;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('检测记录',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const Spacer(),
            if (monitor.lastInspectionTime != null)
              Text('最近检测 ${_fmtTime(monitor.lastInspectionTime!)}',
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
          const SizedBox(height: 4),
          Text('打印中每分钟自动取帧检测，模糊画面直接丢弃（对比度 < $kBlurThreshold）',
              style: TextStyle(fontSize: 11, color: c.textSecondary)),
          if (monitor.lastError != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(LucideIcons.info, size: 12, color: c.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(monitor.lastError!,
                    style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          if (records.isEmpty)
            // 无记录占位
            FlutterNeumorphism(
              style: NeumorphismStyle(
                color: c.background,
                borderRadius: 12,
                depth: 3,
                type: NeumorphismType.flat,
              ),
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(children: [
                  Icon(LucideIcons.camera, size: 26, color: c.textSecondary.withValues(alpha: 0.6)),
                  const SizedBox(height: 8),
                  Text('暂无检测记录',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  const SizedBox(height: 2),
                  Text('打印进行中会每分钟自动检测一次',
                      style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ]),
              ),
            )
          else
            SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _InspectionCard(record: records[i], c: c),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单条检测记录卡片：送检图 + 标注图 + 时间 + 结果/对比度
class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.record, required this.c});

  final AiInspectionRecord record;
  final NeuoColors c;

  @override
  Widget build(BuildContext context) {
    final isAnomaly = record.anomalyDetected;
    final okColor = const Color(0xFF4CAF50);
    return FlutterNeumorphism(
      style: NeumorphismStyle(
        color: c.background,
        borderRadius: 12,
        depth: 4,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _Thumb(image: record.rawImage)),
            const SizedBox(width: 6),
            Expanded(
              child: record.annotatedImage != null
                  ? _Thumb(image: record.annotatedImage!)
                  : _ThumbPlaceholder(label: '未标注'),
            ),
          ]),
          const SizedBox(height: 6),
          Text(_fmtTime(record.time),
              style: TextStyle(fontSize: 10, color: c.textSecondary)),
          const SizedBox(height: 2),
          if (record.discarded)
            Text(record.note ?? '已丢弃',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _red))
          else ...[
            Text(
              '${record.typeLabel}  ${(record.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isAnomaly ? _red : okColor),
            ),
            Text('对比度 ${record.qualityVariance.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// 缩略图
class _Thumb extends StatelessWidget {
  const _Thumb({required this.image});

  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        image,
        width: 118,
        height: 88,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

/// 缩略图占位（标注图缺失时）
class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
      ),
    );
  }
}

String _fmtTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
