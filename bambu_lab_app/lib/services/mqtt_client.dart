/// MQTT 客户端 - 对应 Python PrinterMQTTClient
///
/// 通过 TLS 连接到拓竹打印机，发送命令并接收状态报告
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:bambu_lab_app/models/printer_type.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';

/// Bambu Lab MQTT 客户端
///
/// 管理与打印机的 MQTT TLS 连接，发送控制命令并广播状态更新
class BambuMqttClient {
  BambuMqttClient({
    required this.hostname,
    required this.serial,
    required this.accessCode,
    this.username = 'bblp',
    this.port = 8883,
    this.keepAlivePeriod = 60,
    this.useTls = true,
  });

  final String hostname;
  final String serial;
  final String accessCode;
  final String username;
  final int port;
  final int keepAlivePeriod;
  final bool useTls;

  MqttServerClient? _client;
  String? _lastError;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 最新的完整状态数据（合并所有推送）
  final Map<String, dynamic> _data = {};

  /// Watchdog 计时器 - 60秒无数据则重新请求推送
  Timer? _watchdogTimer;

  /// Watchdog 超时时间（秒）
  static const int _watchdogTimeoutSeconds = 60;

  /// 消息广播流 - 每次收到 MQTT 报告时触发
  Stream<Map<String, dynamic>> get messageStream =>
      _messageController.stream;

  /// 当前完整状态快照
  Map<String, dynamic> get data => Map.unmodifiable(_data);

  /// 是否已连接
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  /// 最后错误信息
  String? get lastError => _lastError;

  /// 命令发布主题
  String get commandTopic => 'device/$serial/request';

  /// 报告订阅主题
  String get reportTopic => 'device/$serial/report';

  /// 连接到打印机 MQTT 服务器
  Future<bool> connect() async {
    final client = MqttServerClient.withPort(
      hostname,
      'bblp_$serial',
      port,
    );

    client.autoReconnect = true;
    client.keepAlivePeriod = keepAlivePeriod;
    client.logging(on: false);
    client.onDisconnected = _onDisconnected;
    // 不在 onConnected 中订阅 — 先设好 _client 和 updates 监听再订阅
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;
    client.onAutoReconnect = _onAutoReconnect;

    // 强制使用 MQTT 3.1.1（协议名 "MQTT"）
    // 默认是 3.1（"MQIsdp"），amqtt 等现代 broker 不支持
    client.setProtocolV311();

    // TLS 设置 - 仅在 useTls 为 true 时启用
    if (useTls) {
      // 跳过证书验证（局域网打印机使用自签名证书）
      final context = SecurityContext(withTrustedRoots: false)
        ..setAlpnProtocols(['mqtt'], false);
      client.securityContext = context;
      client.secure = true;
      client.onBadCertificate = (Object certificate) => true;
    }

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('bblp_$serial')
        .authenticateAs(username, accessCode)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect(username, accessCode);
    } on Exception catch (e) {
      client.disconnect();
      _lastError = e.toString();
      _log('连接失败: $e');
      return false;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _client = client;

      // 先挂上消息监听，再订阅主题
      client.updates!.listen(_onMessage);

      // 订阅报告主题 — MQTT 保证先处理 subscribe 再处理后续 publish，不会漏收
      client.subscribe(reportTopic, MqttQos.atLeastOnce);

      // 订阅后立即请求打印机推送完整状态
      // ⚠️ 注意：不能在 _onConnected 回调里做这些，因为那时 _client 还是 null
      startPush();
      pushAll();
      _startWatchdog();

      return true;
    } else {
      _log('连接状态异常: ${client.connectionStatus}');
      client.disconnect();
      return false;
    }
  }

  /// 断开连接
  void disconnect() {
    _stopWatchdog();
    _client?.disconnect();
    _client = null;
    // 清理状态缓存，确保重连时重新接收完整数据
    _data.clear();
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _messageController.close();
  }

  // --- Watchdog ---

  /// 启动 watchdog 计时器
  void _startWatchdog() {
    _stopWatchdog();
    _watchdogTimer = Timer(
      const Duration(seconds: _watchdogTimeoutSeconds),
      _onWatchdogTimeout,
    );
    _log('Watchdog 已启动 ($_watchdogTimeoutSeconds 秒)');
  }

  /// 重置 watchdog（收到消息时调用）
  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(
      const Duration(seconds: _watchdogTimeoutSeconds),
      _onWatchdogTimeout,
    );
  }

  /// 停止 watchdog
  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  /// Watchdog 超时回调 - 重新请求推送
  void _onWatchdogTimeout() {
    _log('Watchdog 超时，重新请求推送状态');
    if (!isConnected) {
      _log('未连接，等待自动重连');
      _startWatchdog();
      return;
    }
    startPush();
    pushAll();
    // 重启计时器
    _startWatchdog();
  }

  // --- 回调 ---

  void _onConnected() {
    _log('已连接到 MQTT 服务器');
    // 自动重连路径：_client 已存在，重新订阅并请求推送
    // （首次连接的 startPush/pushAll/watchdog 已在 connect() 中完成）
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(reportTopic, MqttQos.atLeastOnce);
      startPush();
      pushAll();
      _startWatchdog();
    }
  }

  void _onDisconnected() {
    _log('MQTT 连接断开');
  }

  void _onSubscribed(String topic) {
    _log('已订阅: $topic');
  }

  void _onAutoReconnect() {
    _log('自动重连中...');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    // 收到消息时重置 watchdog
    _resetWatchdog();

    for (final msg in messages) {
      final pubMsg = msg.payload as MqttPublishMessage;
      final jsonStr = MqttPublishPayload.bytesToStringAsString(
        pubMsg.payload.message,
      );

      _log('收到消息 [${msg.topic}]: $jsonStr');

      try {
        final doc = json.decode(jsonStr) as Map<String, dynamic>;
        _mergeData(doc);
        _messageController.add(doc);
      } on FormatException catch (e) {
        _log('JSON 解析失败: $e');
      }
    }
  }

  /// 合并 MQTT 推送数据到本地状态
  void _mergeData(Map<String, dynamic> incoming) {
    for (final entry in incoming.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic> &&
          _data[key] is Map<String, dynamic>) {
        final existing = _data[key] as Map<String, dynamic>;
        existing.addAll(value);
      } else {
        _data[key] = value;
      }
    }
  }

  // --- 命令发布 ---

  /// 发布原始命令
  bool publishCommand(Map<String, dynamic> payload) {
    final client = _client;
    if (client == null || !isConnected) {
      _log('未连接，无法发送命令');
      return false;
    }
    final jsonStr = json.encode(payload);
    final builder = MqttClientPayloadBuilder()..addString(jsonStr);
    client.publishMessage(
      commandTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    _log('已发送命令: $payload');
    return true;
  }

  /// 请求全量状态推送
  /// 注意：P1 系列需要完整格式，否则可能不响应
  bool pushAll() {
    return publishCommand({
      'pushing': {'command': 'pushall'},
      'info': {'command': 'get_version'},
    });
  }

  /// 开始持续推送（用于 watchdog 超时后重新请求）
  bool startPush() {
    return publishCommand({
      'pushing': {'command': 'start'},
    });
  }

  /// 请求固件版本信息
  bool getInfoVersion() {
    return publishCommand({
      'info': {'command': 'get_version'},
    });
  }

  // --- 打印控制 ---

  /// 停止打印
  bool stopPrint() {
    return publishCommand({
      'print': {'command': 'stop'},
    });
  }

  /// 暂停打印
  bool pausePrint() {
    return publishCommand({
      'print': {'command': 'pause'},
    });
  }

  /// 恢复打印
  bool resumePrint() {
    return publishCommand({
      'print': {'command': 'resume'},
    });
  }

  /// 开始打印 3MF 文件
  bool startPrint3mf({
    required String filename,
    required String plateLocation,
    bool useAms = true,
    List<int> amsMapping = const [0],
    bool bedLeveling = true,
    bool flowCalibration = true,
    bool vibrationCalibration = true,
  }) {
    return publishCommand({
      'print': {
        'command': 'project_file',
        'param': plateLocation,
        'file': filename,
        'bed_leveling': bedLeveling,
        'bed_type': 'textured_plate',
        'flow_cali': flowCalibration,
        'vibration_cali': vibrationCalibration,
        'url': 'ftp:///$filename',
        'layer_inspect': false,
        'sequence_id': '10000000',
        'use_ams': useAms,
        'ams_mapping': amsMapping,
      },
    });
  }

  /// 跳过打印对象
  bool skipObjects(List<int> objectList) {
    return publishCommand({
      'print': {
        'command': 'skip_objects',
        'obj_list': objectList,
      },
    });
  }

  // --- 灯光控制 ---

  /// 开灯
  bool turnLightOn() {
    final ok = publishCommand({
      'system': {'led_mode': 'on'},
    });
    if (ok) pushAll();
    return ok;
  }

  /// 关灯
  bool turnLightOff() {
    final ok = publishCommand({
      'system': {'led_mode': 'off'},
    });
    if (ok) pushAll();
    return ok;
  }

  // --- 温度控制 ---

  /// 发送 G-code 命令
  bool sendGcode(String gcodeCommand) {
    return publishCommand({
      'print': {
        'sequence_id': '0',
        'command': 'gcode_line',
        'param': gcodeCommand,
      },
    });
  }

  /// 设置热床温度
  ///
  /// [temperature] 目标温度（摄氏度）
  bool setBedTemperature(int temperature) {
    return sendGcode('M140 S$temperature\n');
  }

  /// 设置喷嘴温度
  ///
  /// [temperature] 目标温度（摄氏度）
  bool setNozzleTemperature(int temperature) {
    return sendGcode('M104 S$temperature\n');
  }

  // --- 风扇控制 ---

  /// 设置部件风扇速度
  ///
  /// [speed] 0-255
  bool setPartFanSpeed(int speed) {
    _validateFanSpeed(speed);
    return sendGcode('M106 P1 S$speed\n');
  }

  /// 设置辅助风扇速度
  ///
  /// [speed] 0-255
  bool setAuxFanSpeed(int speed) {
    _validateFanSpeed(speed);
    return sendGcode('M106 P2 S$speed\n');
  }

  /// 设置箱体风扇速度
  ///
  /// [speed] 0-255
  bool setChamberFanSpeed(int speed) {
    _validateFanSpeed(speed);
    return sendGcode('M106 P3 S$speed\n');
  }

  void _validateFanSpeed(int speed) {
    if (speed < 0 || speed > 255) {
      throw ArgumentError('风扇速度必须在 0-255 之间: $speed');
    }
  }

  // --- 速度控制 ---

  /// 设置打印速度等级
  ///
  /// [level] 速度等级（1=静音, 2=标准, 3=运动, 4=极限）
  bool setPrintSpeed(int level) {
    return publishCommand({
      'print': {
        'command': 'print_speed',
        'param': '$level',
      },
    });
  }

  // --- 运动控制 ---

  /// 自动归零
  bool autoHome() {
    return sendGcode('G28\n');
  }

  /// 设置热床高度（Z 轴）
  bool setBedHeight(int height) {
    return sendGcode('G90\nG0 Z$height\n');
  }

  // --- 耗材操作 ---

  /// 加载耗材
  bool loadFilament() {
    return publishCommand({
      'print': {
        'command': 'ams_change_filament',
        'target': 255,
        'curr_temp': 215,
        'tar_temp': 215,
      },
    });
  }

  /// 卸载耗材
  bool unloadFilament() {
    return publishCommand({
      'print': {
        'command': 'ams_change_filament',
        'target': 254,
        'curr_temp': 215,
        'tar_temp': 215,
      },
    });
  }

  /// 恢复耗材操作
  bool resumeFilamentAction() {
    return publishCommand({
      'print': {
        'command': 'ams_control',
        'param': 'resume',
      },
    });
  }

  // --- 手动进退料（无AMS时使用）---

  /// 手动进料（无AMS）
  /// 先加热喷嘴到指定温度，然后挤出耗材
  bool manualLoadFilament(int temperature, int extrudeLength) {
    return sendGcode('M104 S$temperature\nG1 E$extrudeLength F300\n');
  }

  /// 手动退料（无AMS）
  /// 先加热喷嘴到指定温度，然后回抽耗材
  bool manualUnloadFilament(int temperature, int retractLength) {
    return sendGcode('M104 S$temperature\nG1 E-$retractLength F300\n');
  }

  // --- 校准 ---

  /// 启动校准
  ///
  /// [bedLeveling] 热床调平
  /// [vibrationCompensation] 振动补偿
  /// [motorNoiseCancellation] 电机噪声消除
  bool calibrate({
    bool bedLeveling = true,
    bool vibrationCompensation = true,
    bool motorNoiseCancellation = true,
  }) {
    var bitmask = 0;
    if (bedLeveling) bitmask |= 1 << 1;
    if (vibrationCompensation) bitmask |= 1 << 2;
    if (motorNoiseCancellation) bitmask |= 1 << 3;

    return publishCommand({
      'print': {
        'command': 'calibration',
        'option': bitmask,
      },
    });
  }

  // --- 系统 ---

  /// 请求访问码
  bool requestAccessCode() {
    return publishCommand({
      'system': {'command': 'get_access_code'},
    });
  }

  /// 重启打印机
  bool reboot() {
    return publishCommand({
      'system': {'command': 'reboot'},
    });
  }

  /// 设置喷嘴信息
  bool setNozzleInfo({
    required String nozzleType,
    double nozzleDiameter = 0.4,
  }) {
    return publishCommand({
      'system': {
        'accessory_type': 'nozzle',
        'command': 'set_accessories',
        'nozzle_diameter': nozzleDiameter,
        'nozzle_type': nozzleType,
      },
    });
  }

  /// 设置自动步进恢复
  bool setAutoStepRecovery({bool enabled = true}) {
    return publishCommand({
      'print': {
        'command': 'gcode_line',
        'auto_recovery': enabled,
      },
    });
  }

  /// 设置延时摄影
  bool setTimelapse({bool enabled = true}) {
    return publishCommand({
      'camera': {
        'command': 'ipcam_record_set',
        'control': enabled ? 'enable' : 'disable',
      },
    });
  }

  // --- 状态读取辅助 ---

  /// 获取当前状态的 print 子字典
  Map<String, dynamic> get printData =>
      (_data['print'] as Map<String, dynamic>?) ?? const {};

  /// 获取当前状态的 info 子字典
  Map<String, dynamic> get infoData =>
      (_data['info'] as Map<String, dynamic>?) ?? const {};

  /// 获取固件版本
  String? get firmwareVersion {
    final modules = infoData['module'];
    if (modules is List) {
      for (final m in modules) {
        if (m is Map<String, dynamic> && m['name'] == 'ota') {
          return m['sw_ver']?.toString();
        }
      }
    }
    return null;
  }

  /// 获取打印机型号（从 info.module[].project_name 提取）
  PrinterType get printerType {
    final modules = infoData['module'];
    if (modules is List) {
      for (final m in modules) {
        if (m is Map<String, dynamic>) {
          final name = m['name'];
          if (name == 'esp32' || name == 'ap' || name == 'ota') {
            final projectName = m['project_name']?.toString();
            if (projectName != null && projectName.isNotEmpty) {
              return PrinterType.fromValue(projectName);
            }
          }
        }
      }
    }
    return PrinterType.unknown;
  }

  void _log(String message) {
    DebugLog.i('MQTT', message);
    // ignore: avoid_print
    print('[BambuMqttClient] $message');
  }
}
