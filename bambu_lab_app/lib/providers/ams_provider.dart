/// AMS 状态 Provider - 从 PrinterProvider 派生 AMS 数据
library;

import 'package:flutter/foundation.dart';

import 'package:bambu_lab_app/models/ams.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';

/// AMS 状态管理器 - 监听打印机状态并提取 AMS 数据
class AmsProvider extends ChangeNotifier {
  AmsProvider(this._printerProvider) {
    _printerProvider.addListener(_onPrinterStateChanged);
  }

  final PrinterProvider _printerProvider;
  AMSHub _hub = const AMSHub();

  /// 当前 AMSHub
  AMSHub get hub => _hub;

  /// 是否连接了 AMS
  bool get hasAms => !_hub.isEmpty;

  /// 获取指定 AMS 单元
  AMS? operator [](int index) => _hub[index];

  /// 所有 AMS 单元
  List<AMS> get all => _hub.all;

  /// AMS 单元数量
  int get count => _hub.count;

  void _onPrinterStateChanged() {
    final newHub = _printerProvider.state.amsHub;
    if (!_hubEquals(_hub, newHub)) {
      _hub = newHub;
      notifyListeners();
    }
  }

  bool _hubEquals(AMSHub a, AMSHub b) {
    if (a.count != b.count) return false;
    for (final key in a.amsHub.keys) {
      final ams = b.amsHub[key];
      if (ams == null) return false;
      final aAms = a.amsHub[key]!;
      if (aAms.humidity != ams.humidity) return false;
      if (aAms.temperature != ams.temperature) return false;
      if (aAms.filamentTrays.length != ams.filamentTrays.length) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _printerProvider.removeListener(_onPrinterStateChanged);
    super.dispose();
  }
}
