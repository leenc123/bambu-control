/// 打印机连接和状态 Provider
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_state.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/services/printer_ftp_service.dart';
import 'package:bambu_lab_app/services/printer_service.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';

/// 打印机连接状态枚举
enum ConnectionStatus { disconnected, connecting, connected, error }

/// 打印机连接和实时状态管理器
class PrinterProvider extends ChangeNotifier {
  PrinterService? _service;
  StreamSubscription<PrinterState>? _stateSubscription;
  PrinterFtpService? _ftp;

  PrinterState _state = const PrinterState();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _errorMessage;

  // 预览图片
  Uint8List? _previewImage;
  bool _loadingPreview = false;
  String? _previewError;

  /// MQTT 获取到型号后的回调（更新数据库用）
  ValueChanged<PrinterType>? onPrinterTypeDetected;

  /// 当前打印机状态
  PrinterState get state => _state;

  /// 连接状态
  ConnectionStatus get connectionStatus => _connectionStatus;

  /// 是否已连接
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 底层服务（连接后可用）
  PrinterService? get service => _service;

  /// 预览图片数据
  Uint8List? get previewImage => _previewImage;

  /// 是否正在加载预览图片
  bool get loadingPreview => _loadingPreview;

  /// 预览图片加载错误
  String? get previewError => _previewError;

  /// FTP 是否已连接
  bool get ftpConnected => _ftp?.isConnected ?? false;

  /// 连接到打印机
  Future<bool> connect(PrinterConfig config) async {
    if (_connectionStatus == ConnectionStatus.connecting) return false;

    // 清理旧连接
    await disconnect();

    _connectionStatus = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    final service = PrinterService(
      hostname: config.ip,
      serial: config.serial,
      accessCode: config.accessCode,
      port: config.port,
      useTls: config.useTls,
    );

    _stateSubscription = service.stateStream.listen(_onStateChanged);

    try {
      final ok = await service.connect();
      if (ok) {
        _service = service;
        _connectionStatus = ConnectionStatus.connected;
        _errorMessage = null;
        // 初始化 FTP 服务（用于获取预览图片等）
        _ftp = PrinterFtpService(host: config.ip, accessCode: config.accessCode);
        // 异步连接 FTP，不阻塞主连接
        _connectFtp();
      } else {
        await service.stateStream.drain<void>();
        service.dispose();
        _connectionStatus = ConnectionStatus.error;
        _errorMessage = service.lastConnectError ?? '连接失败，请检查 IP 和访问码';
      }
    } on Exception catch (e) {
      _connectionStatus = ConnectionStatus.error;
      _errorMessage = '连接异常: $e';
    }

    notifyListeners();
    return isConnected;
  }

  /// 异步连接 FTP
  Future<void> _connectFtp() async {
    if (_ftp == null) return;
    try {
      final ok = await _ftp!.connect();
      if (ok && isConnected) {
        DebugLog.i('FTP', '连接成功');
        // 连接成功后自动获取预览图片
        await fetchPreviewImage();
      } else {
        DebugLog.i('FTP', '连接失败: ${_ftp!.lastError ?? "未知错误"}');
      }
    } catch (e) {
      DebugLog.i('FTP', '连接异常: $e');
    }
    notifyListeners();
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    _service?.dispose();
    _service = null;
    await _ftp?.disconnect();
    _ftp = null;
    _state = const PrinterState();
    _connectionStatus = ConnectionStatus.disconnected;
    _errorMessage = null;
    _previewImage = null;
    _previewError = null;
    notifyListeners();
  }

  /// 获取预览图片（优先从 .3mf 提取缩略图，fallback 到 /image 目录）
  Future<void> fetchPreviewImage() async {
    if (_ftp == null || !_ftp!.isConnected) {
      _previewError = 'FTP 未连接';
      DebugLog.i('PREVIEW', 'FTP 未连接');
      notifyListeners();
      return;
    }

    _loadingPreview = true;
    _previewError = null;
    notifyListeners();

    try {
      Uint8List? image;

      // 优先从 .3mf 提取缩略图（需要 subtaskName / gcodeFile）
      final subtaskName = _state.subtaskName ?? '';
      final gcodeFile = _state.gcodeFile;
      DebugLog.i('PREVIEW', '尝试从 .3mf 提取缩略图: subtaskName=$subtaskName, gcodeFile=$gcodeFile');
      image = await _ftp!.fetchCoverImageFrom3mf(subtaskName, gcodeFile: gcodeFile);
      if (image != null) {
        DebugLog.i('PREVIEW', '.3mf 缩略图提取成功');
      } else {
        DebugLog.i('PREVIEW', '.3mf 缩略图提取失败: ${_ftp!.lastError}');
      }

      // fallback: 从 /image 目录获取摄像头快照
      if (image == null) {
        DebugLog.i('PREVIEW', '回退到 /image 目录获取预览');
        image = await _ftp!.getLatestPreviewImage();
        if (image != null) {
          DebugLog.i('PREVIEW', '/image 预览获取成功');
        } else {
          DebugLog.i('PREVIEW', '/image 预览获取失败: ${_ftp!.lastError}');
        }
      }

      if (image != null) {
        _previewImage = image;
        _previewError = null;
      } else {
        _previewError = _ftp!.lastError ?? '获取预览图片失败';
      }
    } catch (e) {
      _previewError = '获取预览图片异常: $e';
      DebugLog.i('PREVIEW', '预览异常: $e');
    }

    _loadingPreview = false;
    notifyListeners();
  }

  /// 乐观更新状态并通知 UI
  void _optimisticUpdate({bool? lightOn}) {
    _state = _state.copyWith(lightOn: lightOn);
    notifyListeners();
  }

  void _onStateChanged(PrinterState newState) {
    // 首次获取到型号 → 回调通知上层写入数据库
    if (_state.printerType == PrinterType.unknown &&
        newState.printerType != PrinterType.unknown) {
      onPrinterTypeDetected?.call(newState.printerType);
    }

    // 检测到新的打印任务开始 → 自动刷新预览图
    final prevFile = _state.subtaskName;
    final newFile = newState.subtaskName;
    if (prevFile != newFile && newFile != null && newFile.isNotEmpty) {
      fetchPreviewImage();
    }

    _state = newState;
    notifyListeners();
  }

  // --- 快捷方法（委托给 PrinterService）---

  Future<bool> stopPrint() async => _service?.stopPrint() ?? false;
  Future<bool> pausePrint() async => _service?.pausePrint() ?? false;
  Future<bool> resumePrint() async => _service?.resumePrint() ?? false;

  /// 开灯（乐观更新：立即刷新 UI，不等打印机响应）
  Future<bool> turnLightOn() async {
    _optimisticUpdate(lightOn: true);
    return _service?.turnLightOn() ?? false;
  }

  /// 关灯（乐观更新：立即刷新 UI，不等打印机响应）
  Future<bool> turnLightOff() async {
    _optimisticUpdate(lightOn: false);
    return _service?.turnLightOff() ?? false;
  }

  /// 切换灯光（乐观更新：立即刷新 UI，不等打印机响应）
  Future<bool> toggleLight() async {
    // 先做乐观翻转
    _optimisticUpdate(lightOn: !_state.lightOn);
    // 再发命令（PrinterService 的内部状态不受本次翻转影响，仍能正确判断当前状态）
    return _service?.toggleLight() ?? false;
  }

  Future<bool> setBedTemperature(int t) async =>
      _service?.setBedTemperature(t) ?? false;
  Future<bool> setNozzleTemperature(int t) async =>
      _service?.setNozzleTemperature(t) ?? false;
  Future<bool> setPartFanSpeed(int s) async =>
      _service?.setPartFanSpeed(s) ?? false;
  Future<bool> setAuxFanSpeed(int s) async =>
      _service?.setAuxFanSpeed(s) ?? false;
  Future<bool> setPrintSpeed(int l) async =>
      _service?.setPrintSpeed(l) ?? false;
  Future<bool> autoHome() async => _service?.autoHome() ?? false;
  Future<bool> sendGcode(String cmd) async =>
      _service?.sendGcode(cmd) ?? false;
  Future<bool> skipPrintObject() async =>
      _service?.skipObjects(const []) ?? false;
  Future<bool> calibrate({bool bedLevel = true, bool motorNoise = true, bool vibration = true}) async =>
      _service?.calibrate(bedLeveling: bedLevel, motorNoiseCancellation: motorNoise, vibrationCompensation: vibration) ?? false;
  bool pushAll() => _service?.pushAll() ?? false;

  // --- 进退料（有AMS用自动，无AMS用手动）---

  /// 进料（有AMS自动进料，无AMS需要手动）
  Future<bool> loadFilament() async => _service?.loadFilament() ?? false;

  /// 退料（有AMS自动退料，无AMS需要手动）
  Future<bool> unloadFilament() async => _service?.unloadFilament() ?? false;

  /// 手动进料（无AMS时使用，需指定温度和挤出长度）
  Future<bool> manualLoadFilament(int temperature, int extrudeLength) async =>
      _service?.manualLoadFilament(temperature, extrudeLength) ?? false;

  /// 手动退料（无AMS时使用，需指定温度和回抽长度）
  Future<bool> manualUnloadFilament(int temperature, int retractLength) async =>
      _service?.manualUnloadFilament(temperature, retractLength) ?? false;

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _service?.dispose();
    _ftp?.disconnect();
    super.dispose();
  }
}
