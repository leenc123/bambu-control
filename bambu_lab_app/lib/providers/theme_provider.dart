/// 主题切换 Provider — 三态: system / light / dark
library;

import 'package:flutter/material.dart';

class ThemeModeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  set mode(ThemeMode v) {
    if (_mode != v) {
      _mode = v;
      notifyListeners();
    }
  }

  void setSystem() => mode = ThemeMode.system;
  void setLight() => mode = ThemeMode.light;
  void setDark() => mode = ThemeMode.dark;

  /// 根据当前 mode 返回实际使用的 Brightness
  Brightness resolveBrightness(BuildContext context) {
    return switch (_mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
  }
}
