import 'package:bambu_lab_app/models/ams.dart';
import 'package:bambu_lab_app/models/gcode_state.dart';
import 'package:bambu_lab_app/models/print_status.dart';
import 'package:bambu_lab_app/models/printer_type.dart';

/// 打印机状态聚合模型 - 对应 Python client 中的状态解析
///
/// 不可变数据类，每次状态更新创建新实例
class PrinterState {
  const PrinterState({
    this.printStatus = PrintStatus.unknown,
    this.gcodeState = GcodeState.unknown,
    this.bedTemp,
    this.nozzleTemp,
    this.chamberTemp,
    this.printPercentage,
    this.remainingTime,
    this.fanSpeed,
    this.auxFanSpeed,
    this.lightOn = false,
    this.amsHub = const AMSHub(),
    this.printerType = PrinterType.unknown,
    this.nozzleType = NozzleType.stainlessSteel,
    this.wifiSignal,
    this.printSpeed = 100,
    this.firmwareVersion,
    this.serialNumber,
    this.printErrorCode,
    this.online = false,
    this.hasAms = false,
  });

  final PrintStatus printStatus;
  final GcodeState gcodeState;
  final double? bedTemp;
  final double? nozzleTemp;
  final double? chamberTemp;
  final int? printPercentage;
  final int? remainingTime;
  final int? fanSpeed;
  final int? auxFanSpeed;
  final bool lightOn;
  final AMSHub amsHub;
  final PrinterType printerType;
  final NozzleType nozzleType;
  final int? wifiSignal;
  final int printSpeed;
  final String? firmwareVersion;
  final String? serialNumber;
  final String? printErrorCode;
  final bool online;
  final bool hasAms;

  /// 创建更新后的新实例（不可变模式）
  PrinterState copyWith({
    PrintStatus? printStatus,
    GcodeState? gcodeState,
    double? bedTemp,
    double? nozzleTemp,
    double? chamberTemp,
    int? printPercentage,
    int? remainingTime,
    int? fanSpeed,
    int? auxFanSpeed,
    bool? lightOn,
    AMSHub? amsHub,
    PrinterType? printerType,
    NozzleType? nozzleType,
    int? wifiSignal,
    int? printSpeed,
    String? firmwareVersion,
    String? serialNumber,
    String? printErrorCode,
    bool? online,
    bool? hasAms,
  }) {
    return PrinterState(
      printStatus: printStatus ?? this.printStatus,
      gcodeState: gcodeState ?? this.gcodeState,
      bedTemp: bedTemp ?? this.bedTemp,
      nozzleTemp: nozzleTemp ?? this.nozzleTemp,
      chamberTemp: chamberTemp ?? this.chamberTemp,
      printPercentage: printPercentage ?? this.printPercentage,
      remainingTime: remainingTime ?? this.remainingTime,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      auxFanSpeed: auxFanSpeed ?? this.auxFanSpeed,
      lightOn: lightOn ?? this.lightOn,
      amsHub: amsHub ?? this.amsHub,
      printerType: printerType ?? this.printerType,
      nozzleType: nozzleType ?? this.nozzleType,
      wifiSignal: wifiSignal ?? this.wifiSignal,
      printSpeed: printSpeed ?? this.printSpeed,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      printErrorCode: printErrorCode ?? this.printErrorCode,
      online: online ?? this.online,
      hasAms: hasAms ?? this.hasAms,
    );
  }

  /// 从 MQTT report JSON 解析状态（基于 command 类型分派）
  factory PrinterState.fromMqttReport(
    Map<String, dynamic> report, {
    PrinterState? previous,
  }) {
    final base = previous ?? const PrinterState();

    // 检查消息类型，按 command 分派处理
    final print = report['print'] as Map<String, dynamic>?;
    final info = report['info'] as Map<String, dynamic>?;

    // 1. get_version 消息 → 更新设备信息（型号、AMS 存在性）
    if (info != null && info['command'] == 'get_version') {
      return base.copyWith(
        printerType: _parsePrinterTypeFromInfo(info) ?? base.printerType,
        firmwareVersion: _parseFirmwareVersion(report),
        hasAms: _checkAmsExist(info),
        online: true,
      );
    }

    // 2. push_status 消息 → 只更新消息中存在的字段
    if (print != null && (print['command'] == 'push_status' || print.containsKey('gcode_state'))) {
      // 只有字段存在时才更新，否则保留之前的值
      final gcodeState = print.containsKey('gcode_state')
          ? GcodeState.fromValue(print['gcode_state']?.toString())
          : base.gcodeState;
      final printStatus = print.containsKey('gcode_state')
          ? _derivePrintStatus(gcodeState)
          : base.printStatus;

      return base.copyWith(
        printStatus: printStatus,
        gcodeState: gcodeState,
        bedTemp: print.containsKey('bed_temper') ? _toDouble(print['bed_temper']) : null,
        nozzleTemp: print.containsKey('nozzle_temper') ? _toDouble(print['nozzle_temper']) : null,
        chamberTemp: print.containsKey('chamber_temper') ? _toDouble(print['chamber_temper']) : null,
        printPercentage: print.containsKey('mc_percent') ? _toInt(print['mc_percent']) : null,
        remainingTime: print.containsKey('mc_remaining_time') ? _toInt(print['mc_remaining_time']) : null,
        fanSpeed: print.containsKey('cooling_fan_speed') ? _toInt(print['cooling_fan_speed']) : null,
        auxFanSpeed: print.containsKey('aux_part_fan_speed') ? _toInt(print['aux_part_fan_speed']) : null,
        lightOn: print.containsKey('lights_report') || print.containsKey('light_mode') ? _parseLightOn(print) : null,
        amsHub: print.containsKey('ams') ? _parseAms(print) : null,
        wifiSignal: print.containsKey('wifi_signal') ? _parseWifiSignal(print['wifi_signal']) : null,
        printSpeed: print.containsKey('spd_lvl') ? _toInt(print['spd_lvl']) ?? base.printSpeed : null,
        printErrorCode: print.containsKey('print_error') ? print['print_error']?.toString() : null,
        online: true,
      );
    }

    // 其他消息类型，保持原状态
    return base.copyWith(online: true);
  }

  /// 从 info.module 检测 AMS 是否存在（通过SN号判断）
  static bool _checkAmsExist(Map<String, dynamic> info) {
    final modules = info['module'];
    if (modules is List) {
      for (final m in modules) {
        if (m is Map<String, dynamic>) {
          final name = m['name']?.toString().toLowerCase() ?? '';
          if (name.contains('ams')) {
            // 检查SN号是否有效（不为空且不是占位符）
            final sn = m['sn']?.toString() ?? '';
            if (sn.isNotEmpty &&
                sn != 'STUDY0ONLY' &&
                sn != 'NULL' &&
                sn.length > 5) {  // 真实SN号通常较长
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// 解析 wifi_signal（去掉 dBm 后缀）
  static int? _parseWifiSignal(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      // 移除 "dBm" 后缀并解析数字
      final clean = value.replaceAll('dBm', '').trim();
      return int.tryParse(clean);
    }
    return null;
  }

  /// 从 gcode_state 派生打印状态
  static PrintStatus _derivePrintStatus(GcodeState gcodeState) {
    switch (gcodeState) {
      case GcodeState.idle:
        return PrintStatus.idle;
      case GcodeState.running:
      case GcodeState.prepare:
      case GcodeState.slicing:
        return PrintStatus.printing;
      case GcodeState.pause:
        return PrintStatus.pausedUser;
      case GcodeState.finish:
        return PrintStatus.idle;
      case GcodeState.failed:
        return PrintStatus.unknown;
      case GcodeState.init:
      case GcodeState.offline:
      case GcodeState.unknown:
        return PrintStatus.unknown;
    }
  }

  /// 从 info.module 中提取固件版本
  static String? _parseFirmwareVersion(Map<String, dynamic> report) {
    final info = report['info'] as Map<String, dynamic>?;
    if (info == null) return null;
    final modules = info['module'];
    if (modules is List) {
      for (final m in modules) {
        if (m is Map<String, dynamic> && m['name'] == 'ota') {
          return m['sw_ver']?.toString();
        }
      }
    }
    return null;
  }

  /// 从 info.module[].project_name 提取打印机型号
  /// 参考: https://github.com/bambulab/BambuStudio/tree/master/resources/printers
  static PrinterType? _parsePrinterTypeFromInfo(Map<String, dynamic> info) {
    final modules = info['module'];
    if (modules is List) {
      for (final m in modules) {
        if (m is Map<String, dynamic>) {
          // 优先从 esp32/ap/ota 模块获取 project_name
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
    return null;  // 未找到型号时返回 null，保留之前值
  }

  /// 格式化剩余时间
  String get remainingTimeFormatted {
    if (remainingTime == null || remainingTime == 0) return '--:--';
    final hours = remainingTime! ~/ 60;
    final minutes = remainingTime! % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// 温度显示字符串
  String get bedTempDisplay =>
      bedTemp != null ? '${bedTemp!.toStringAsFixed(1)}°C' : '--';
  String get nozzleTempDisplay =>
      nozzleTemp != null ? '${nozzleTemp!.toStringAsFixed(1)}°C' : '--';
  String get chamberTempDisplay =>
      chamberTemp != null ? '${chamberTemp!.toStringAsFixed(1)}°C' : '--';

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _parseLightOn(Map<String, dynamic> print) {
    final lightReport = print['lights_report'];
    if (lightReport is List && lightReport.isNotEmpty) {
      final first = lightReport[0];
      if (first is Map<String, dynamic>) {
        return first['mode']?.toString() == 'on';
      }
    }
    return print['light_mode']?.toString() == '1';
  }

  /// 解析 AMS 数据（嵌套在 print.ams.ams 中）
  static AMSHub _parseAms(Map<String, dynamic> print) {
    final amsObj = print['ams'];
    if (amsObj is Map<String, dynamic>) {
      final amsList = amsObj['ams'];
      if (amsList is List) {
        return AMSHub.fromList(amsList);
      }
    }
    return const AMSHub();
  }
}
