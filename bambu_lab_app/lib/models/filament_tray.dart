import 'package:bambu_lab_app/models/filament.dart';

/// 耗材料盘数据类 - 对应 Python FilamentTray
class FilamentTray {
  const FilamentTray({
    required this.k,
    required this.n,
    required this.tagUid,
    required this.trayIdName,
    required this.trayInfoIdx,
    required this.trayType,
    required this.traySubBrands,
    required this.trayColor,
    required this.trayWeight,
    required this.trayDiameter,
    required this.trayTemp,
    required this.trayTime,
    required this.bedTempType,
    required this.bedTemp,
    required this.nozzleTempMax,
    required this.nozzleTempMin,
    required this.xcamInfo,
    required this.trayUuid,
    this.cols,
  });

  final double k;
  final int n;
  final String tagUid;
  final String trayIdName;
  final String trayInfoIdx;
  final String trayType;
  final String traySubBrands;
  final String trayColor;
  final String trayWeight;
  final String trayDiameter;
  final String trayTemp;
  final String trayTime;
  final String bedTempType;
  final String bedTemp;
  final int nozzleTempMax;
  final int nozzleTempMin;
  final String xcamInfo;
  final String trayUuid;
  final List<String>? cols;

  /// 从 MQTT JSON 字典创建
  factory FilamentTray.fromMap(Map<String, dynamic> map) {
    return FilamentTray(
      k: _toDouble(map['k'] ?? 0),
      n: _toInt(map['n'] ?? 0),
      tagUid: map['tag_uid']?.toString() ?? '',
      trayIdName: map['tray_id_name']?.toString() ?? '',
      trayInfoIdx: map['tray_info_idx']?.toString() ?? '',
      trayType: map['tray_type']?.toString() ?? '',
      traySubBrands: map['tray_sub_brands']?.toString() ?? '',
      trayColor: map['tray_color']?.toString() ?? '',
      trayWeight: map['tray_weight']?.toString() ?? '',
      trayDiameter: map['tray_diameter']?.toString() ?? '',
      trayTemp: map['tray_temp']?.toString() ?? '',
      trayTime: map['tray_time']?.toString() ?? '',
      bedTempType: map['bed_temp_type']?.toString() ?? '',
      bedTemp: map['bed_temp']?.toString() ?? '',
      nozzleTempMax: _toInt(map['nozzle_temp_max'] ?? 0),
      nozzleTempMin: _toInt(map['nozzle_temp_min'] ?? 0),
      xcamInfo: map['xcam_info']?.toString() ?? '',
      trayUuid: map['tray_uuid']?.toString() ?? '',
      cols: map['cols'] is List
          ? List<String>.from(map['cols'])
          : null,
    );
  }

  /// 获取匹配的耗材类型
  Filament? get filament => Filament.fromTrayInfoIdx(trayInfoIdx);

  /// 耗材颜色（十六进制，去掉 alpha 通道前两位）
  String get displayColor {
    if (trayColor.length == 8) {
      return '#${trayColor.substring(2)}';
    }
    return '#$trayColor';
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
