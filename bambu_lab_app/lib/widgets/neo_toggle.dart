/// 拟物风格开关按钮（与校准面板的开关同款）
///
/// 按压态胶囊 + "开/关" 文本：开启 = 按压态 + 强调色，关闭 = 平面 + 次级色。
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';

class NeoToggle extends StatefulWidget {
  const NeoToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.c,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final NeuoColors c;

  @override
  State<NeoToggle> createState() => _NeoToggleState();
}

class _NeoToggleState extends State<NeoToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onChanged(!value);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 12,
          depth: _pressed ? 2 : (value ? 3 : 5),
          type: _pressed
              ? NeumorphismType.pressed
              : (value ? NeumorphismType.pressed : NeumorphismType.flat),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          value ? '开' : '关',
          style: TextStyle(
            fontSize: 12,
            fontWeight: value ? FontWeight.w600 : FontWeight.w400,
            color: value ? widget.c.accent : widget.c.textSecondary,
          ),
        ),
      ),
    );
  }
}
