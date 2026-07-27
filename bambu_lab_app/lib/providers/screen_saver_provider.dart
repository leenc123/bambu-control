/// 屏保 Provider — 追踪闲置时间，超时通知 UI 叠加黑屏
///
/// 仅在 Android / iOS 上启用 wakelock（保持屏幕常亮），
/// Linux / Windows 桌面端不需要亮屏功能。
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock/wakelock.dart';

/// Wakelock 仅在需要「保持屏幕常亮」的移动端开启
bool get _shouldKeepScreenOn =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class ScreenSaverProvider extends ChangeNotifier {
  final Duration idleTimeout;
  DateTime _lastInteraction;
  bool _isActive = false;
  Timer? _timer;

  ScreenSaverProvider({this.idleTimeout = const Duration(minutes: 5)})
      : _lastInteraction = DateTime.now() {
    // 仅在 Android/iOS 上保持屏幕常亮
    if (_shouldKeepScreenOn) {
      Wakelock.enable();
    }
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
    if (_shouldKeepScreenOn) {
      Wakelock.disable();
    }
    super.dispose();
  }
}
