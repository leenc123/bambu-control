/// 灯光开关组件
library;


import 'package:flutter/material.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';

class LightToggle extends StatelessWidget {
  const LightToggle({
    super.key,
    required this.printer,
  });

  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    final isOn = printer.state.lightOn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3A5160).withValues(alpha:0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isOn ? Icons.lightbulb : Icons.lightbulb_outline,
            color: isOn ? Colors.amber : Color(0xFF3A5160),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '打印灯光',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF253840),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOn ? '已开启' : '已关闭',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF3A5160),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            onChanged: (value) async {
              await printer.toggleLight();
            },
            activeThumbColor: Color(0xFF2633C5),
          ),
        ],
      ),
    );
  }
}
