/// AI 监控 Provider — 打印中每分钟取帧检测
///
/// 对齐 Python 插件 coordinator 的流程：
///   取帧 → 质量过滤（模糊丢弃）→ /analyze → /visualize → 连续检出计数 → 自动暂停
///
/// 规则：
/// - 仅在打印机已连接且 `printStatus == printing` 时取帧（每分钟一次）
/// - 送检前 Laplacian 方差 < [kBlurThreshold] 视为模糊，直接丢弃不检测
/// - 置信度 ≥ 配置阈值才计入连续检出；连续 ≥ aiMaxConsecutive 且开启自动暂停时暂停打印
/// - RTSP 机型（X1 系）暂不支持自动取帧（无 RTSP 实现），跳过并记录提示
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/models/print_status.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/services/ai_service.dart';
import 'package:bambu_lab_app/services/bambu_camera.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';

/// 一次检测记录（送检图 + 标注图 + 结果）
class AiInspectionRecord {
  const AiInspectionRecord({
    required this.time,
    required this.rawImage,
    this.annotatedImage,
    required this.anomalyDetected,
    required this.anomalyType,
    required this.confidence,
    required this.qualityVariance,
    this.note,
  });

  final DateTime time;

  /// 送检原图（JPEG）
  final Uint8List rawImage;

  /// 检测后标注图（JPEG；模糊丢弃或 visualize 失败时为 null）
  final Uint8List? annotatedImage;

  final bool anomalyDetected;
  final String anomalyType;
  final double confidence;

  /// 对比度（Laplacian 方差），≥ [kBlurThreshold] 视为清晰
  final double qualityVariance;

  /// 备注（如"画面模糊已丢弃"、"RTSP 暂不支持"）
  final String? note;

  String get typeLabel => kAnomalyTypeLabels[anomalyType] ?? anomalyType;

  /// 是否因质量不足被丢弃（未送检）
  bool get discarded => note != null && !anomalyDetected && annotatedImage == null;
}

class AiMonitorProvider extends ChangeNotifier {
  AiMonitorProvider(this._printer, this._configs) {
    _printer.addListener(_onPrinterChanged);
    _configs.addListener(_onPrinterChanged);
  }

  static const _interval = Duration(minutes: 1);
  static const _maxRecords = 20;
  static const _frameWaitTimeout = Duration(seconds: 12);

  final PrinterProvider _printer;
  final PrinterConfigProvider _configs;

  Timer? _timer;
  BambuCamera? _camera;
  bool _running = false;
  bool _ticking = false; // 并发守卫：一次只允许一个检测在途
  int _consecutive = 0;

  final List<AiInspectionRecord> _records = [];
  String? _lastError;
  DateTime? _lastInspectionTime;

  /// 检测记录（最新在前，最多 [_maxRecords] 条）
  List<AiInspectionRecord> get records => List.unmodifiable(_records);

  /// 最近的错误/提示信息
  String? get lastError => _lastError;

  /// 最近一次检测（含丢弃）时间
  DateTime? get lastInspectionTime => _lastInspectionTime;

  /// 监控是否运行中（打印机已连接）
  bool get isMonitoring => _running;

  /// 连续检出次数（用于 UI 展示）
  int get consecutiveCount => _consecutive;

  void _onPrinterChanged() {
    final connected = _printer.isConnected;
    final cfg = _configs.selected;
    if (connected && cfg != null) {
      _ensureStarted();
    } else {
      _stop();
    }
  }

  void _ensureStarted() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(_interval, (_) => _tick());
    _tick(); // 立即执行一次（内部会判断是否打印中）
  }

  void _stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _camera?.stop();
    _camera = null;
  }

  Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final cfg = _configs.selected;
      if (cfg == null || !_printer.isConnected) return;

      // 仅在打印中取帧；暂停/空闲/校准均跳过
      if (_printer.state.printStatus != PrintStatus.printing) return;

      // 机型区分：仅 6000 TLS 长连接机型支持自动取帧
      final kind = cfg.printerType.cameraKind;
      if (kind != CameraKind.tls6000) {
        _lastError = '${cfg.printerType.displayName} 为 RTSP 机型，自动取帧暂未接入';
        notifyListeners();
        return;
      }

      // 取帧（长连接复用，见 BambuCamera）
      final camera = _camera ??= BambuCamera(
            host: cfg.ip,
            accessCode: cfg.accessCode,
          );
      Uint8List frame;
      try {
        frame = await camera.captureFrame(waitTimeout: _frameWaitTimeout);
      } on BambuCameraException catch (e) {
        _lastError = '取帧失败: ${e.message}';
        DebugLog.i('AI', _lastError!);
        notifyListeners();
        return;
      }

      // 送检前质量判断：模糊直接丢弃，不送检
      final variance = await checkImageQuality(frame);
      final now = DateTime.now();
      if (variance < kBlurThreshold) {
        _addRecord(AiInspectionRecord(
          time: now,
          rawImage: frame,
          anomalyDetected: false,
          anomalyType: 'none',
          confidence: 0,
          qualityVariance: variance,
          note: '画面模糊，已丢弃（对比度 ${variance.toStringAsFixed(0)}，阈值 $kBlurThreshold）',
        ));
        _lastInspectionTime = now;
        notifyListeners();
        return;
      }

      // 送检分析
      final result = await analyzeImage(frame);

      // 标注图（失败不阻塞记录）
      final annotated = await visualizeImage(frame);

      // 连续检出 + 自动暂停（对齐 Python 插件）
      final isAnomaly =
          result.anomalyDetected && result.confidence >= cfg.aiConfidenceThreshold;
      if (isAnomaly) {
        _consecutive++;
        if (_consecutive >= cfg.aiMaxConsecutive && cfg.aiAutoPause) {
          await _printer.pausePrint();
          _lastError = '连续 $_consecutive 次检出异常，已自动暂停打印';
          DebugLog.i('AI', _lastError!);
        }
      } else {
        _consecutive = 0;
      }

      _addRecord(AiInspectionRecord(
        time: now,
        rawImage: frame,
        annotatedImage: annotated,
        anomalyDetected: isAnomaly,
        anomalyType: result.anomalyType,
        confidence: result.confidence,
        qualityVariance: variance,
      ));
      _lastInspectionTime = now;
      notifyListeners();
    } finally {
      _ticking = false;
    }
  }

  void _addRecord(AiInspectionRecord r) {
    _records.insert(0, r);
    if (_records.length > _maxRecords) {
      _records.removeRange(_maxRecords, _records.length);
    }
  }

  /// 手动立即检测一次（调试/测试用）
  Future<void> inspectNow() => _tick();

  @override
  void dispose() {
    _printer.removeListener(_onPrinterChanged);
    _configs.removeListener(_onPrinterChanged);
    _stop();
    super.dispose();
  }
}
