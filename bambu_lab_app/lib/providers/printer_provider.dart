/// 打印机连接和状态 Provider
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bambu_lab_app/models/printer_config.dart';
import 'package:bambu_lab_app/models/printer_state.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/services/printer_service.dart';

/// 打印机连接状态枚举
enum ConnectionStatus { disconnected, connecting, connected, error }

/// 打印机连接和实时状态管理器
class PrinterProvider extends ChangeNotifier {
  PrinterService? _service;
  StreamSubscription<PrinterState>? _stateSubscription;

  PrinterState _state = const PrinterState();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _errorMessage;

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

  /// 断开连接
  Future<void> disconnect() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    _service?.dispose();
    _service = null;
    _state = const PrinterState();
    _connectionStatus = ConnectionStatus.disconnected;
    _errorMessage = null;
    notifyListeners();
  }

  void _onStateChanged(PrinterState newState) {
    // 首次获取到型号 → 回调通知上层写入数据库
    if (_state.printerType == PrinterType.unknown &&
        newState.printerType != PrinterType.unknown) {
      onPrinterTypeDetected?.call(newState.printerType);
    }
    _state = newState;
    notifyListeners();
  }

  // --- 快捷方法（委托给 PrinterService）---

  Future<bool> stopPrint() async => _service?.stopPrint() ?? false;
  Future<bool> pausePrint() async => _service?.pausePrint() ?? false;
  Future<bool> resumePrint() async => _service?.resumePrint() ?? false;
  Future<bool> turnLightOn() async => _service?.turnLightOn() ?? false;
  Future<bool> turnLightOff() async => _service?.turnLightOff() ?? false;
  Future<bool> toggleLight() async => _service?.toggleLight() ?? false;
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
  Future<bool> calibrate({bool bedLevel = true, bool motorNoise = true, bool vibration = true}) async =>
      _service?.calibrate(bedLeveling: bedLevel, motorNoiseCancellation: motorNoise, vibrationCompensation: vibration) ?? false;
  bool pushAll() => _service?.pushAll() ?? false;

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _service?.dispose();
    super.dispose();
  }
}
