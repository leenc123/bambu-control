/// 灯光开关组件
library;

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
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
        color: FitnessAppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: FitnessAppTheme.grey.withValues(alpha:0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isOn ? Icons.lightbulb : Icons.lightbulb_outline,
            color: isOn ? Colors.amber : FitnessAppTheme.grey,
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
                    color: FitnessAppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOn ? '已开启' : '已关闭',
                  style: TextStyle(
                    fontSize: 14,
                    color: FitnessAppTheme.grey,
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
            activeThumbColor: FitnessAppTheme.nearlyDarkBlue,
          ),
        ],
      ),
    );
  }
}
