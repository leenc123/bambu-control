/// 打印机型号 → 素材图匹配（支持灯光状态切换）
library;

import 'package:bambu_lab_app/models/printer_type.dart';

/// 根据型号和灯光状态返回对应图片路径
String? printerImageByType(PrinterType type, {bool lightOn = false}) {
  // 有开灯图的型号优先返回灯光版
  if (lightOn) {
    return switch (type) {
      PrinterType.a1Mini => 'assets/printer_images/a1_mini-light-on.png',
      PrinterType.a1  => 'assets/printer_images/a1-light-on.png',
      PrinterType.p1p => 'assets/printer_images/p1p-light-on.png',
      PrinterType.a2l => 'assets/printer_images/a2l-light-on.png',
      _ => null, // 其他型号暂无双版本图片，走默认
    };
  }
  return switch (type) {
    PrinterType.x1c => 'assets/printer_images/x1c.png',
    PrinterType.x1e => 'assets/printer_images/x1e.png',
    PrinterType.x1 => 'assets/printer_images/x1c.png',
    PrinterType.p1s => 'assets/printer_images/p1s.png',
    PrinterType.p1p => 'assets/printer_images/p1p.png',
    PrinterType.a2l => 'assets/printer_images/a2l.png',
    PrinterType.a1  => 'assets/printer_images/a1.png',
    PrinterType.a1Mini => 'assets/printer_images/a1_mini.png',
    PrinterType.unknown => null,
  };
}

/// 名称模糊匹配（未连接时 fallback）
String? printerImageByName(String? name) {
  if (name == null || name.isEmpty) return null;
  final n = name.toLowerCase();
  if (n.contains('x1e')) return 'assets/printer_images/x1e.png';
  if (n.contains('x1 carbon') || n.contains('x1c')) return 'assets/printer_images/x1c.png';
  if (n.contains('x1')) return 'assets/printer_images/x1c.png';
  if (n.contains('p1s')) return 'assets/printer_images/p1s.png';
  if (n.contains('p1p')) return 'assets/printer_images/p1p.png';
  if (n.contains('a2l')) return 'assets/printer_images/a2l.png';
  if (n.contains('a1 mini')) return 'assets/printer_images/a1_mini.png';
  if (n.contains('a1')) return 'assets/printer_images/a1.png';
  return null;
}

/// 综合匹配（带灯光状态）
String? printerImage(String? name, PrinterType type, {bool lightOn = false}) =>
    printerImageByType(type, lightOn: lightOn) ?? printerImageByName(name);
