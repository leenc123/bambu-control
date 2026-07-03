/// 打印机服务 - 对应 Python Printer 类
///
/// 统一封装 MQTT 客户端和打印机状态，提供高级 API
library;

import 'dart:async';

import 'package:bambu_lab_app/models/ams.dart';
import 'package:bambu_lab_app/models/filament.dart';
import 'package:bambu_lab_app/models/gcode_state.dart';
import 'package:bambu_lab_app/models/printer_state.dart';
import 'package:bambu_lab_app/models/print_status.dart';
import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/services/mqtt_client.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';

/// 打印机服务 - 整合 MQTT 通信和状态管理
class PrinterService {
  PrinterService({
    required this.hostname,
    required this.serial,
    required this.accessCode,
    int? port,
    bool? useTls,
  }) : _mqtt = BambuMqttClient(
          hostname: hostname,
          serial: serial,
          accessCode: accessCode,
          port: port ?? (useTls == false ? 1883 : 8883),
          useTls: useTls ?? true,
        );

  final String hostname;
  final String serial;
  final String accessCode;

  final BambuMqttClient _mqtt;

  /// MQTT 消息监听器（需在断开时取消）
  StreamSubscription<Map<String, dynamic>>? _mqttSubscription;

  /// 当前打印机状态
  PrinterState _state = const PrinterState();

  /// 状态变化通知流
  final StreamController<PrinterState> _stateController =
      StreamController<PrinterState>.broadcast();

  /// 状态变化流
  Stream<PrinterState> get stateStream => _stateController.stream;

  /// 当前状态快照
  PrinterState get currentState => _state;

  /// 是否已连接
  bool get isConnected => _mqtt.isConnected;

  // --- 连接管理 ---

  /// 连接到打印机
  Future<bool> connect() async {
    // 取消旧监听器，避免重复订阅
    await _mqttSubscription?.cancel();
    DebugLog.i('SVC', '正在连接打印机...');
    _mqttSubscription = _mqtt.messageStream.listen(_handleMessage);
    final ok = await _mqtt.connect();
    if (ok) {
      DebugLog.i('SVC', '连接成功');
      _updateState(_state.copyWith(online: true));
    } else {
      DebugLog.i('SVC', '连接失败: ${_mqtt.lastError ?? "未知"}');
    }
    return ok;
  }

  /// 获取最后连接错误（用于失败原因展示）
  String? get lastConnectError => _mqtt.lastError;

  /// 断开连接
  void disconnect() {
    _mqttSubscription?.cancel();
    _mqttSubscription = null;
    _mqtt.disconnect();
    _updateState(_state.copyWith(online: false));
  }

  /// 释放资源
  void dispose() {
    _mqttSubscription?.cancel();
    _mqttSubscription = null;
    _mqtt.dispose();
    _stateController.close();
  }

  // --- 消息处理 ---

  void _handleMessage(Map<String, dynamic> msg) {
    final newState = PrinterState.fromMqttReport(msg, previous: _state);
    // AMS 数据已经在 fromMqttReport 中解析(print.ams),不需要再次处理
    _updateState(newState);
    DebugLog.i('SVC', '状态更新: ${_state.printStatus.displayName} '
        'bed=${_state.bedTemp} nozzle=${_state.nozzleTemp} '
        'progress=${_state.printPercentage}%');
    // ignore: avoid_print
    print('[PrinterService] 状态更新: gcode=${_state.gcodeState.displayName}, '
        'status=${_state.printStatus.displayName}, '
        'bed=${_state.bedTemp}, nozzle=${_state.nozzleTemp}, '
        'progress=${_state.printPercentage}%, '
        'printerType=${_state.printerType.displayName}, '
        'hasAms=${_state.hasAms}');
  }

  void _updateState(PrinterState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  // --- 状态读取快捷方法 ---

  PrintStatus get printStatus => _state.printStatus;
  GcodeState get gcodeState => _state.gcodeState;
  double? get bedTemperature => _state.bedTemp;
  double? get nozzleTemperature => _state.nozzleTemp;
  double? get chamberTemperature => _state.chamberTemp;
  int? get printPercentage => _state.printPercentage;
  int? get remainingTime => _state.remainingTime;
  int? get fanSpeed => _state.fanSpeed;
  int? get auxFanSpeed => _state.auxFanSpeed;
  bool get isLightOn => _state.lightOn;
  AMSHub get amsHub => _state.amsHub;
  String? get firmwareVersion => _state.firmwareVersion;
  int get printSpeed => _state.printSpeed;

  // --- 打印控制 ---

  /// 开始打印 3MF 文件
  Future<bool> startPrint({
    required String filename,
    required int plateNumber,
    bool useAms = true,
    List<int> amsMapping = const [0],
  }) async {
    final plateLocation = 'Metadata/plate_$plateNumber.gcode';
    return _mqtt.startPrint3mf(
      filename: filename,
      plateLocation: plateLocation,
      useAms: useAms,
      amsMapping: amsMapping,
    );
  }

  /// 停止打印
  Future<bool> stopPrint() async => _mqtt.stopPrint();

  /// 暂停打印
  Future<bool> pausePrint() async => _mqtt.pausePrint();

  /// 恢复打印
  Future<bool> resumePrint() async => _mqtt.resumePrint();

  /// 跳过打印对象
  Future<bool> skipObjects(List<int> objectList) async =>
      _mqtt.skipObjects(objectList);

  // --- 温度控制 ---

  /// 设置热床温度
  Future<bool> setBedTemperature(int temperature) async =>
      _mqtt.setBedTemperature(temperature);

  /// 设置喷嘴温度
  Future<bool> setNozzleTemperature(int temperature) async =>
      _mqtt.setNozzleTemperature(temperature);

  // --- 风扇控制 ---

  /// 设置部件风扇速度 (0-255)
  Future<bool> setPartFanSpeed(int speed) async =>
      _mqtt.setPartFanSpeed(speed);

  /// 设置辅助风扇速度 (0-255)
  Future<bool> setAuxFanSpeed(int speed) async =>
      _mqtt.setAuxFanSpeed(speed);

  /// 设置箱体风扇速度 (0-255)
  Future<bool> setChamberFanSpeed(int speed) async =>
      _mqtt.setChamberFanSpeed(speed);

  // --- 灯光控制 ---

  /// 开灯
  Future<bool> turnLightOn() async => _mqtt.turnLightOn();

  /// 关灯
  Future<bool> turnLightOff() async => _mqtt.turnLightOff();

  /// 切换灯光
  Future<bool> toggleLight() async {
    if (_state.lightOn) {
      return turnLightOff();
    } else {
      return turnLightOn();
    }
  }

  // --- 速度控制 ---

  /// 设置打印速度等级 (1=静音, 2=标准, 3=运动, 4=极限)
  Future<bool> setPrintSpeed(int level) async =>
      _mqtt.setPrintSpeed(level);

  // --- 运动控制 ---

  /// 自动归零
  Future<bool> autoHome() async => _mqtt.autoHome();

  /// 设置热床高度（Z 轴）
  Future<bool> setBedHeight(int height) async =>
      _mqtt.setBedHeight(height);

  // --- G-code ---

  /// 发送 G-code 命令
  Future<bool> sendGcode(String command) async =>
      _mqtt.sendGcode(command);

  // --- 耗材操作 ---

  /// 加载耗材
  Future<bool> loadFilament() async => _mqtt.loadFilament();

  /// 卸载耗材
  Future<bool> unloadFilament() async => _mqtt.unloadFilament();

  /// 恢复耗材操作
  Future<bool> resumeFilamentAction() async =>
      _mqtt.resumeFilamentAction();

  /// 手动进料（无AMS时使用）
  Future<bool> manualLoadFilament(int temperature, int extrudeLength) async =>
      _mqtt.manualLoadFilament(temperature, extrudeLength);

  /// 手动退料（无AMS时使用）
  Future<bool> manualUnloadFilament(int temperature, int retractLength) async =>
      _mqtt.manualUnloadFilament(temperature, retractLength);

  /// 设置打印机耗材
  Future<bool> setPrinterFilament({
    required AMSFilamentSettings filament,
    required String color,
    int amsId = 255,
    int trayId = 254,
  }) async {
    return _mqtt.publishCommand({
      'print': {
        'command': 'ams_filament_setting',
        'ams_id': amsId,
        'tray_id': trayId,
        'tray_info_idx': filament.trayInfoIdx,
        'tray_color': '${color.toUpperCase()}FF',
        'nozzle_temp_min': filament.nozzleTempMin,
        'nozzle_temp_max': filament.nozzleTempMax,
        'tray_type': filament.trayType,
      },
    });
  }

  // --- 校准 ---

  /// 启动校准
  Future<bool> calibrate({
    bool bedLeveling = true,
    bool vibrationCompensation = true,
    bool motorNoiseCancellation = true,
  }) async {
    return _mqtt.calibrate(
      bedLeveling: bedLeveling,
      vibrationCompensation: vibrationCompensation,
      motorNoiseCancellation: motorNoiseCancellation,
    );
  }

  // --- 系统 ---

  /// 重启打印机
  Future<bool> reboot() async => _mqtt.reboot();

  /// 请求全量状态刷新
  bool pushAll() => _mqtt.pushAll();

  /// 设置喷嘴信息
  Future<bool> setNozzleInfo({
    required NozzleType nozzleType,
    double diameter = 0.4,
  }) async {
    return _mqtt.setNozzleInfo(
      nozzleType: nozzleType.value,
      nozzleDiameter: diameter,
    );
  }

  /// 设置延时摄影
  Future<bool> setTimelapse({bool enabled = true}) async =>
      _mqtt.setTimelapse(enabled: enabled);
}
