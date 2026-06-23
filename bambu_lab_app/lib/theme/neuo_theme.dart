/// 软拟物 (Neumorphic) 主题
library;

import 'package:flutter/material.dart';

/// 软拟物主题色
class NeuoColors {
  final Color background;
  final Color lightShadow;
  final Color darkShadow;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const NeuoColors({
    required this.background,
    required this.lightShadow,
    required this.darkShadow,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  /// 浅色 — 纯白背景，深阴影
  static const light = NeuoColors(
    background: Color(0xFFE8E8EC),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0x26000000),
    accent: Color(0xFF034C27),
    textPrimary: Color(0xFF16162A),
    textSecondary: Color(0xFF727280),
  );

  /// 深色 — 更深背景，亮阴影更明显
  static const dark = NeuoColors(
    background: Color(0xFF141418),
    lightShadow: Color(0x18FFFFFF),
    darkShadow: Color(0xDD000000),
    accent: Color(0xFF4CAF78),
    textPrimary: Color(0xFFEEEEF4),
    textSecondary: Color(0xFF8A8A98),
  );
}

/// 软拟物主题 InheritedWidget
class NeuoTheme extends InheritedWidget {
  final NeuoColors colors;

  const NeuoTheme({
    required this.colors,
    required super.child,
    super.key,
  });

  static NeuoColors of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<NeuoTheme>();
    assert(w != null, 'NeuoTheme not found in widget tree');
    return w!.colors;
  }

  @override
  bool updateShouldNotify(NeuoTheme old) => colors != old.colors;
}
