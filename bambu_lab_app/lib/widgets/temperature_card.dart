/// 温度显示卡片 - 圆角白色背景显示温度
library;

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';

class TemperatureCard extends StatelessWidget {
  const TemperatureCard({
    super.key,
    required this.title,
    required this.temperature,
    required this.icon,
    required this.color,
  });

  final String title;
  final double? temperature;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: FitnessAppTheme.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: FitnessAppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            temperature != null
                ? '${temperature!.toStringAsFixed(1)}°C'
                : '--',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
