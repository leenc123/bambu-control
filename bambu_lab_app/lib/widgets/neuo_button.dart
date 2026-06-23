/// 软拟物按钮 — 凸起 + 按压凹陷反馈
library;

import 'package:flutter/material.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';

/// 软拟物按钮
///
/// 支持凸起样式，按压自动切换凹陷。
/// [icon] + [label] 可组合，至少提供一个。
class NeuoButton extends StatefulWidget {
  final Widget? icon;
  final Widget? label;
  final VoidCallback? onPressed;
  final double borderRadius;
  final double depth;
  final double intensity;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? accentColor;
  final MainAxisSize mainAxisSize;

  const NeuoButton({
    this.icon,
    this.label,
    this.onPressed,
    this.borderRadius = 14,
    this.depth = 5,
    this.intensity = 0.8,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.backgroundColor,
    this.accentColor,
    this.mainAxisSize = MainAxisSize.min,
    super.key,
  });

  /// 纯图标按钮
  const NeuoButton.icon({
    required Widget icon,
    VoidCallback? onPressed,
    double borderRadius = 14,
    double depth = 5,
    double intensity = 0.8,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    Color? backgroundColor,
    Color? accentColor,
    Key? key,
  }) : this(
          key: key,
          icon: icon,
          label: null,
          onPressed: onPressed,
          borderRadius: borderRadius,
          depth: depth,
          intensity: intensity,
          padding: padding,
          backgroundColor: backgroundColor,
          accentColor: accentColor,
        );

  /// FAB 风格（强调色背景 + 白色图标/文字）
  factory NeuoButton.fab({
    required VoidCallback? onPressed,
    Widget? icon,
    Widget? label,
    double borderRadius = 16,
    double depth = 6,
    double intensity = 0.9,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 14,
    ),
    Color? accentColor,
    Key? key,
  }) {
    return NeuoButton(
      key: key,
      icon: icon,
      label: label,
      onPressed: onPressed,
      borderRadius: borderRadius,
      depth: depth,
      intensity: intensity,
      padding: padding,
      accentColor: accentColor,
    );
  }

  @override
  State<NeuoButton> createState() => _NeuoButtonState();
}

class _NeuoButtonState extends State<NeuoButton> {
  bool _pressed = false;

  void _onTapDown(_) {
    if (widget.onPressed != null) setState(() => _pressed = true);
  }

  void _onTapUp(_) {
    if (widget.onPressed != null) {
      setState(() => _pressed = false);
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = NeuoTheme.of(context);
    final ac = widget.accentColor ?? colors.accent;
    final bg = widget.backgroundColor ?? colors.background;

    // FAB 风格：用 accentColor 做背景
    final isFab = widget.accentColor != null;
    final cardBg = isFab ? ac : bg;

    // 文字/图标颜色
    final fgColor = isFab ? Colors.white : ac;

    final double d = widget.depth * widget.intensity;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    offset: Offset(-d * 0.3, -d * 0.3),
                    blurRadius: d * 0.6,
                    color: colors.darkShadow,
                  ),
                  BoxShadow(
                    offset: Offset(d * 0.3, d * 0.3),
                    blurRadius: d * 0.6,
                    color: colors.lightShadow,
                  ),
                ]
              : [
                  BoxShadow(
                    offset: Offset(-d * 0.5, -d * 0.5),
                    blurRadius: d * 1.0,
                    color: colors.lightShadow,
                  ),
                  BoxShadow(
                    offset: Offset(d * 0.5, d * 0.5),
                    blurRadius: d * 1.0,
                    color: colors.darkShadow,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: widget.mainAxisSize,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: fgColor,
                  size: widget.label != null ? 20 : 22,
                ),
                child: widget.icon!,
              ),
              if (widget.label != null) const SizedBox(width: 8),
            ],
            if (widget.label != null)
              DefaultTextStyle(
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                child: widget.label!,
              ),
          ],
        ),
      ),
    );
  }
}
