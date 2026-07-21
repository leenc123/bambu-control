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
    this.keepAlivePeriod = 15,
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
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSubscription;
  String? _lastError;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 最新的完整状态数据（合并所有推送）
  final Map<String, dynamic> _data = {};

  /// Watchdog 计时器 - 60秒无数据则重新请求推送
  Timer? _watchdogTimer;

  /// 初始数据等待计时器 - 订阅后短时间未收到数据则重试
  Timer? _initialDataTimer;

  /// 标记等待初始推送，在 _onSubscribed 中清除并发送命令
  bool _pendingInitialPush = false;

  /// 初始数据重试次数（最多 2 次）
  int _initialDataRetries = 0;

  /// Watchdog 超时时间（秒）— 2 倍 keepalive，连接断开后能更快检测到
  static const int _watchdogTimeoutSeconds = 30;

  /// 初始数据等待超时（秒）
  static const int _initialDataTimeoutSeconds = 15;

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
    // 使用唯一 client ID 避免 amqtt broker 的 session 残留 bug（HA 组件同样做法）
    final clientId = 'bblp_${serial}_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(
      hostname,
      clientId,
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
      // 注意：不设置 ALPN，拓竹打印机的 MQTT broker 不支持 ALPN 协商 'mqtt'
      final context = SecurityContext(withTrustedRoots: false);
      client.securityContext = context;
      client.secure = true;
      client.onBadCertificate = (Object certificate) => true;
    }

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
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

      // 先挂上消息监听（自动重连后 _onConnected 会重新监听，防止 stream 被替换）
      _updatesSubscription?.cancel();
      _updatesSubscription = client.updates!.listen(_onMessage);

      // subscribe 实际返回时 SUBACK 可能还没到，
      // 命令移到 _onSubscribed 回调里发，确保订阅在 broker 端生效后再请求推送
      _pendingInitialPush = true;
      await client.subscribe(reportTopic, MqttQos.atLeastOnce);

      return true;
    } else {
      _log('连接状态异常: ${client.connectionStatus}');
      client.disconnect();
      return false;
    }
  }

  /// 断开连接
  void disconnect() {
    _pendingInitialPush = false;
    _stopInitialDataTimer();
    _stopWatchdog();
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
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

  /// 启动初始数据等待计时器
  ///
  /// 订阅后短时间（15秒）内未收到任何消息，重试 pushAll。
  /// 最多重试 2 次，之后交给 watchdog 兜底。
  void _startInitialDataTimer() {
    _initialDataTimer?.cancel();
    _initialDataRetries = 0;
    _initialDataTimer = Timer(
      const Duration(seconds: _initialDataTimeoutSeconds),
      _onInitialDataTimeout,
    );
    _log('初始数据等待中 ($_initialDataTimeoutSeconds 秒)');
  }

  /// 取消初始数据等待计时器（收到消息时调用）
  void _stopInitialDataTimer() {
    _initialDataTimer?.cancel();
    _initialDataTimer = null;
    _initialDataRetries = 0;
  }

  /// 初始数据超时 — 重试 pushAll
  void _onInitialDataTimeout() {
    if (_initialDataRetries >= 2) {
      _log('初始数据重试已达上限，等待下次 watchdog 重连');
      return;
    }
    _initialDataRetries++;
    _log('初始数据超时，第 $_initialDataRetries 次重试 pushAll');
    pushAll();
    _initialDataTimer = Timer(
      const Duration(seconds: _initialDataTimeoutSeconds),
      _onInitialDataTimeout,
    );
  }

  /// Watchdog 超时回调 — 断开并重建连接
  ///
  /// 如果只重发命令，连接挂死（打印机 MQTT session 卡住）时永远得不到回复。
  /// 全量断线重连 → 新 CONNECT（clean session）→ 新 SUBSCRIBE → pushall，
  /// 打印机侧也会建立新 session，恢复正常推送。
  Future<void> _onWatchdogTimeout() async {
    _log('Watchdog 超时，强制重连...');
    _pendingInitialPush = false;
    _stopInitialDataTimer();

    // 全量断开 — 先禁用自动重连，避免旧客户端和新连接并发
    _stopWatchdog();
    if (_client != null) {
      _client!.autoReconnect = false;
      _client!.disconnect();
    }
    _client = null;
    _data.clear();

    // 重建连接（内部走 _onSubscribed → startPush + pushAll）
    final ok = await connect();
    if (!ok) {
      _log('Watchdog 重连失败，60 秒后重试');
      _startWatchdog();
    }
  }

  // --- 回调 ---

  Future<void> _onConnected() async {
    _log('已连接到 MQTT 服务器');
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      // 自动重连后重新监听 updates stream（mqtt_client 可能会替换 stream）
      _updatesSubscription?.cancel();
      _updatesSubscription = _client!.updates!.listen(_onMessage);

      // 命令在 _onSubscribed 中统一发送，确保订阅生效后再请求推送
      _pendingInitialPush = true;
      await _client!.subscribe(reportTopic, MqttQos.atLeastOnce);
    }
  }

  void _onDisconnected() {
    _log('MQTT 连接断开');
  }

  void _onSubscribed(String topic) {
    _log('已订阅: $topic');
    // SUBACK 确认后，订阅已在 broker 生效，再发命令确保不丢失回复
    if (_pendingInitialPush) {
      _pendingInitialPush = false;
      // 分开发送命令，不要合并到一条消息里。HA 组件也是分开发送的。
      getInfoVersion();  // 先请求固件版本
      pushAll();         // 再请求全量状态
      // 如果打印机刚建立连接还未就绪，15 秒内未收到消息会重试 pushAll
      _startInitialDataTimer();
      _startWatchdog();
    }
  }

  void _onAutoReconnect() {
    _log('自动重连中...');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    // 收到第一条消息后，取消初始数据等待计时器
    _stopInitialDataTimer();

    for (final msg in messages) {
      final pubMsg = msg.payload as MqttPublishMessage;
      final rawBytes = pubMsg.payload.message;

      // 兼容非 UTF-8 编码：先试 UTF-8，失败则用 Latin-1 兜底（HA 组件同样策略）
      String jsonStr;
      try {
        jsonStr = utf8.decode(rawBytes);
      } catch (_) {
        // UTF-8 解码失败（含 FormatException 和其他编码错误），用 Latin-1 逐字节保留
        try {
          jsonStr = latin1.decode(rawBytes);
        } catch (_) {
          _log('消息解码失败: 无法解析字节数据 [${msg.topic}]');
          continue;
        }
      }

      _log('收到消息 [${msg.topic}]: $jsonStr');

      try {
        final doc = json.decode(jsonStr) as Map<String, dynamic>;
        _mergeData(doc);
        _messageController.add(doc);
        // 仅当消息成功解析后才重置 watchdog，避免无效数据续命
        _resetWatchdog();
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
    final bytes = builder.payload;
    if (bytes == null) {
      _log('命令序列化失败: payload builder 返回 null');
      return false;
    }
    try {
      client.publishMessage(
        commandTopic,
        MqttQos.atLeastOnce,
        bytes,
      );
      _log('已发送命令: $jsonStr');
      return true;
    } catch (e) {
      _log('发送命令失败: $e');
      return false;
    }
  }

  /// 请求全量状态推送
  /// 注意：P1 系列需要完整格式，否则可能不响应
  /// 按协议要求加 sequence_id，且只发 pushall（get_version 分开单独发）
  bool pushAll() {
    return publishCommand({
      'pushing': {'sequence_id': '0', 'command': 'pushall'},
    });
  }

  /// 开始持续推送（用于 watchdog 超时后重新请求，而不是断开重连）
  bool startPush() {
    return publishCommand({
      'pushing': {'sequence_id': '0', 'command': 'start'},
    });
  }

  /// 请求固件版本信息
  bool getInfoVersion() {
    return publishCommand({
      'info': {'sequence_id': '0', 'command': 'get_version'},
    });
  }

  // --- 打印控制 ---

  /// 停止打印
  bool stopPrint() {
    return publishCommand({
      'print': {'sequence_id': '0', 'command': 'stop'},
    });
  }

  /// 暂停打印
  bool pausePrint() {
    return publishCommand({
      'print': {'sequence_id': '0', 'command': 'pause'},
    });
  }

  /// 恢复打印
  bool resumePrint() {
    return publishCommand({
      'print': {'sequence_id': '0', 'command': 'resume'},
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
        'sequence_id': '0',
        'command': 'skip_objects',
        'obj_list': objectList,
      },
    });
  }

  // --- 灯光控制 ---

  /// 开灯
  /// 注：不内联 pushAll，避免命令到达顺序颠倒。下次 watchdog push 会自动更新状态。
  bool turnLightOn() {
    return publishCommand({
      'system': {'sequence_id': '0', 'command': 'ledctrl', 'led_node': 'chamber_light', 'led_mode': 'on', 'led_on_time': 500, 'led_off_time': 500, 'loop_times': 0, 'interval_time': 0},
    });
  }

  /// 关灯
  bool turnLightOff() {
    return publishCommand({
      'system': {'sequence_id': '0', 'command': 'ledctrl', 'led_node': 'chamber_light', 'led_mode': 'off', 'led_on_time': 500, 'led_off_time': 500, 'loop_times': 0, 'interval_time': 0},
    });
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
        'sequence_id': '0',
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
        'sequence_id': '0',
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
        'sequence_id': '0',
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
        'sequence_id': '0',
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
        'sequence_id': '0',
        'command': 'calibration',
        'option': bitmask,
      },
    });
  }

  // --- 系统 ---

  /// 请求访问码
  bool requestAccessCode() {
    return publishCommand({
      'system': {'sequence_id': '0', 'command': 'get_access_code'},
    });
  }

  /// 重启打印机
  bool reboot() {
    return publishCommand({
      'system': {'sequence_id': '0', 'command': 'reboot'},
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
        'sequence_id': '0',
        'command': 'gcode_line',
        'auto_recovery': enabled,
      },
    });
  }

  /// 设置延时摄影
  bool setTimelapse({bool enabled = true}) {
    return publishCommand({
      'camera': {
        'sequence_id': '0',
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
