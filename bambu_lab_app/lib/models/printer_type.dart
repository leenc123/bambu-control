/// 打印机型号枚举 - 基于 BambuStudio 官方 project_name 代码
/// 参考: https://github.com/bambulab/BambuStudio/tree/master/resources/printers
enum PrinterType {
  // A 系列 (project_name)
  a1Mini('N1'),       // A1 Mini
  a1('N2S'),          // A1
  a2l('N9'),          // A2L (2026年6月发布)

  // P 系列 (project_name)
  p1p('C11'),         // P1P
  p1s('C12'),         // P1S

  // X 系列 (project_name 或 product_name)
  x1('3DPrinter-X1'),         // X1
  x1c('3DPrinter-X1-Carbon'), // X1-Carbon
  x1e('C13'),                 // X1E

  unknown('UNKNOWN');

  const PrinterType(this.value);

  final String value;

  static PrinterType fromValue(String? value) {
    if (value == null) return unknown;
    for (final type in PrinterType.values) {
      if (type.value == value) return type;
    }
    return unknown;
  }

  String get displayName => switch (this) {
        PrinterType.a1Mini => 'Bambu Lab A1 Mini',
        PrinterType.a1 => 'Bambu Lab A1',
        PrinterType.a2l => 'Bambu Lab A2L',
        PrinterType.p1p => 'Bambu Lab P1P',
        PrinterType.p1s => 'Bambu Lab P1S',
        PrinterType.x1 => 'Bambu Lab X1',
        PrinterType.x1c => 'Bambu Lab X1-Carbon',
        PrinterType.x1e => 'Bambu Lab X1E',
        PrinterType.unknown => '未知型号',
      };

  /// 是否支持 AMS (A1 Mini/A1 支持 AMS Lite, A2L 支持 AMS 2 Pro 和 AMS Lite)
  bool get supportsAms => switch (this) {
        PrinterType.a1Mini ||
        PrinterType.a1 ||
        PrinterType.a2l ||
        PrinterType.p1s ||
        PrinterType.p1p ||
        PrinterType.x1 ||
        PrinterType.x1c ||
        PrinterType.x1e =>
          true,
        _ => false,
      };

  /// 是否有摄像头
  /// A1/A1 Mini/A2L: JPEG 帧拉取 (端口 6000)
  /// P1S/P1P/X1 系列: RTSP 流
  bool get hasCamera => switch (this) {
        PrinterType.a1Mini ||
        PrinterType.a1 ||
        PrinterType.a2l ||
        PrinterType.p1s ||
        PrinterType.p1p ||
        PrinterType.x1 ||
        PrinterType.x1c ||
        PrinterType.x1e =>
          true,
        _ => false,
      };

  /// 是否有箱体温度传感器
  /// X1/X1C/X1E/P1S 为全封闭机型，有箱体温度检测
  /// P1P/A1/A1 Mini 为开放框架，无机箱温度
  /// A2L 虽为封闭机型但暂无箱体温度数据
  bool get hasChamberTemp => switch (this) {
        PrinterType.x1 ||
        PrinterType.x1c ||
        PrinterType.x1e ||
        PrinterType.p1s =>
          true,
        _ => false,
      };

  /// 是否支持双喷头
  /// 当前所有机型均为单喷头，预留未来扩展
  bool get hasDualNozzle => switch (this) {
        _ => false,
      };
}

/// 喷嘴类型枚举 - 对应 Python NozzleType
enum NozzleType {
  stainlessSteel('stainless_steel'),
  hardenedSteel('hardened_steel');

  const NozzleType(this.value);

  final String value;

  static NozzleType fromValue(String? value) {
    for (final type in NozzleType.values) {
      if (type.value == value) return type;
    }
    return stainlessSteel;
  }

  String get displayName => switch (this) {
        NozzleType.stainlessSteel => '不锈钢喷嘴',
        NozzleType.hardenedSteel => '硬化钢喷嘴',
      };
}
