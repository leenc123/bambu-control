/// 屏保 Provider — 追踪闲置时间，超时通知 UI 叠加黑屏
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenSaverProvider extends ChangeNotifier {
  final Duration idleTimeout;
  DateTime _lastInteraction;
  bool _isActive = false;
  Timer? _timer;

  ScreenSaverProvider({this.idleTimeout = const Duration(minutes: 5)})
      : _lastInteraction = DateTime.now() {
    // 保持屏幕常亮
    WakelockPlus.enable();
    // 每秒检查一次闲置时间
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  bool get isActive => _isActive;

  /// 用户操作时调用，重置计时器
  void resetTimer() {
    _lastInteraction = DateTime.now();
    if (_isActive) {
      _isActive = false;
      notifyListeners();
    }
  }

  void _check() {
    if (!_isActive &&
        DateTime.now().difference(_lastInteraction) >= idleTimeout) {
      _isActive = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}
