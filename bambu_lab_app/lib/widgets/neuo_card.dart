/// 软拟物卡片 — 凸起容器，可选按压凹陷动画
library;

import 'package:flutter/material.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';

/// 卡片样式
enum NeuoShape { convex, concave, flat }

/// 软拟物卡片
///
/// [onTap] 非空时按压自动从 convex 切换为 concave 并回弹。
class NeuoCard extends StatefulWidget {
  final Widget child;
  final NeuoShape shape;
  final double borderRadius;
  final double depth;        // 阴影深度，越大越立体
  final double intensity;    // 亮度强度 0~1
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor; // 默认取 NeuoColors.background

  const NeuoCard({
    required this.child,
    this.shape = NeuoShape.convex,
    this.borderRadius = 16,
    this.depth = 6,
    this.intensity = 0.7,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    super.key,
  });

  @override
  State<NeuoCard> createState() => _NeuoCardState();
}

class _NeuoCardState extends State<NeuoCard> {
  bool _pressed = false;

  void _onTapDown(_) {
    if (widget.onTap != null) setState(() => _pressed = true);
  }

  void _onTapUp(_) {
    if (widget.onTap != null) {
      setState(() => _pressed = false);
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = NeuoTheme.of(context);
    final bg = widget.backgroundColor ?? colors.background;

    final currentShape = _pressed ? NeuoShape.concave : widget.shape;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        margin: widget.margin,
        padding: widget.padding,
        decoration: _decoration(currentShape, bg, colors),
        child: widget.child,
      ),
    );
  }

  BoxDecoration _decoration(NeuoShape shape, Color bg, NeuoColors colors) {
    final double d = widget.depth * widget.intensity;
    return BoxDecoration(
      color: shape == NeuoShape.flat ? bg : bg,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      boxShadow: switch (shape) {
        NeuoShape.convex => [
            BoxShadow(
              offset: Offset(-d * 0.6, -d * 0.6),
              blurRadius: d * 1.2,
              color: colors.lightShadow,
            ),
            BoxShadow(
              offset: Offset(d * 0.6, d * 0.6),
              blurRadius: d * 1.2,
              color: colors.darkShadow,
            ),
          ],
        NeuoShape.concave => [
            BoxShadow(
              offset: Offset(-d * 0.4, -d * 0.4),
              blurRadius: d * 0.8,
              color: colors.darkShadow,
            ),
            BoxShadow(
              offset: Offset(d * 0.4, d * 0.4),
              blurRadius: d * 0.8,
              color: colors.lightShadow,
            ),
          ],
        NeuoShape.flat => [],
      },
    );
  }
}
