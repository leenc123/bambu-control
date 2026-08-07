import 'package:bambu_lab_app/models/printer_type.dart';

/// 打印机配置 - 存储在本地数据库中的连接信息
class PrinterConfig {
  const PrinterConfig({
    this.id,
    required this.name,
    required this.ip,
    required this.serial,
    required this.accessCode,
    this.useTls = true,
    this.printerType = PrinterType.unknown,
    this.aiConfidenceThreshold = 0.5,
    this.aiMaxConsecutive = 3,
    this.aiAutoPause = true,
    this.lastConnected,
    this.createdAt,
  });

  /// 数据库主键（新建时为 null）
  final int? id;
  final String name;
  final String ip;
  final String serial;
  final String accessCode;

  /// 是否使用 TLS 连接（默认 true，测试时可设为 false）
  final bool useTls;

  /// 打印机型号（连接后从 MQTT 获取或手动选择）
  final PrinterType printerType;

  // ---- AI 检测配置 ----

  /// 检测置信度阈值（0~1），高于此值才算检出异常，默认 0.5
  final double aiConfidenceThreshold;

  /// 最大连续检出次数，连续超过该次数才判定为打印缺陷，默认 3
  final int aiMaxConsecutive;

  /// 判定缺陷后是否自动暂停打印，默认 true
  final bool aiAutoPause;

  final DateTime? lastConnected;
  final DateTime? createdAt;

  /// MQTT 端口（根据 useTls 自动推导：TLS=8883，非TLS=1883）
  int get port => useTls ? 8883 : 1883;

  /// 创建更新后的新实例
  PrinterConfig copyWith({
    int? id,
    String? name,
    String? ip,
    String? serial,
    String? accessCode,
    bool? useTls,
    PrinterType? printerType,
    double? aiConfidenceThreshold,
    int? aiMaxConsecutive,
    bool? aiAutoPause,
    DateTime? lastConnected,
    DateTime? createdAt,
  }) {
    return PrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      serial: serial ?? this.serial,
      accessCode: accessCode ?? this.accessCode,
      useTls: useTls ?? this.useTls,
      printerType: printerType ?? this.printerType,
      aiConfidenceThreshold: aiConfidenceThreshold ?? this.aiConfidenceThreshold,
      aiMaxConsecutive: aiMaxConsecutive ?? this.aiMaxConsecutive,
      aiAutoPause: aiAutoPause ?? this.aiAutoPause,
      lastConnected: lastConnected ?? this.lastConnected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 从数据库行创建
  factory PrinterConfig.fromMap(Map<String, dynamic> map) {
    return PrinterConfig(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      ip: map['ip'] as String? ?? '',
      serial: map['serial'] as String? ?? '',
      accessCode: map['access_code'] as String? ?? '',
      useTls: map['use_tls'] == 1 || map['use_tls'] == true,
      printerType: PrinterType.fromValue(map['printer_type'] as String?),
      aiConfidenceThreshold: (map['ai_confidence_threshold'] as num?)?.toDouble() ?? 0.5,
      aiMaxConsecutive: (map['ai_max_consecutive'] as num?)?.toInt() ?? 3,
      aiAutoPause: map['ai_auto_pause'] == 1 || map['ai_auto_pause'] == true,
      lastConnected: map['last_connected'] != null
          ? DateTime.tryParse(map['last_connected'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'ip': ip,
      'serial': serial,
      'access_code': accessCode,
      'use_tls': useTls ? 1 : 0,
      'printer_type': printerType.value,
      'ai_confidence_threshold': aiConfidenceThreshold,
      'ai_max_consecutive': aiMaxConsecutive,
      'ai_auto_pause': aiAutoPause ? 1 : 0,
      'last_connected': lastConnected?.toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// 显示名称（含 IP 信息）
  String get displayName => '$name ($ip)';
}
