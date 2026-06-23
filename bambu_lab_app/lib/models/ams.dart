import 'package:bambu_lab_app/models/filament_tray.dart';

/// AMS 自动换料系统 - 对应 Python AMS
class AMS {
  AMS({
    required this.humidity,
    required this.temperature,
    Map<int, FilamentTray>? filamentTrays,
  }) : filamentTrays = filamentTrays ?? {};

  final int humidity;
  final double temperature;
  final Map<int, FilamentTray> filamentTrays;

  /// 从 MQTT JSON 创建
  factory AMS.fromMap(Map<String, dynamic> map) {
    final trays = <int, FilamentTray>{};
    if (map['tray'] is List) {
      for (final t in map['tray'] as List) {
        if (t is Map<String, dynamic>) {
          final id = t['id'];
          if (id != null) {  // 只需要 id 存在，不需要 n 字段
            final trayId = int.tryParse(id.toString()) ?? 0;
            trays[trayId] = FilamentTray.fromMap(t);
          }
        }
      }
    }
    return AMS(
      humidity: int.tryParse(map['humidity']?.toString() ?? '0') ?? 0,
      temperature:
          double.tryParse(map['temp']?.toString() ?? '0') ?? 0.0,  // JSON 用的是 temp，不是 temperature
      filamentTrays: trays,
    );
  }

  /// 获取指定索引的料盘
  FilamentTray? getTray(int index) => filamentTrays[index];

  /// 设置料盘
  void setTray(int index, FilamentTray tray) =>
      filamentTrays[index] = tray;

  /// 湿度百分比描述
  String get humidityDescription => switch (humidity) {
        <= 20 => '干燥',
        <= 40 => '正常',
        <= 60 => '偏湿',
        _ => '潮湿',
      };
}

/// AMS 集线器 - 对应 Python AMSHub
/// 管理多个 AMS 单元
class AMSHub {
  const AMSHub({Map<int, AMS>? amsHub}) : amsHub = amsHub ?? const {};

  final Map<int, AMS> amsHub;

  /// 从 MQTT JSON 列表解析
  factory AMSHub.fromList(List<dynamic> list) {
    final hub = <int, AMS>{};
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final id = item['id'];
        if (id != null) {
          hub[int.tryParse(id.toString()) ?? 0] = AMS.fromMap(item);
        }
      }
    }
    return AMSHub(amsHub: hub);
  }

  /// 获取指定 AMS 单元
  AMS? operator [](int index) => amsHub[index];

  /// 获取所有 AMS 单元
  List<AMS> get all => amsHub.values.toList();

  /// AMS 单元数量
  int get count => amsHub.length;

  /// 是否有任何 AMS 连接
  bool get isEmpty => amsHub.isEmpty;
}
