/// 风扇控制组件 - 滑块调节风扇速度
library;

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';

class FanControlWidget extends StatefulWidget {
  const FanControlWidget({
    super.key,
    required this.printer,
  });

  final PrinterProvider printer;

  @override
  State<FanControlWidget> createState() => _FanControlWidgetState();
}

class _FanControlWidgetState extends State<FanControlWidget> {
  double _partFanSpeed = 0;
  double _auxFanSpeed = 0;

  @override
  void initState() {
    super.initState();
    _updateSpeeds();
    widget.printer.addListener(_updateSpeeds);
  }

  void _updateSpeeds() {
    setState(() {
      _partFanSpeed = (widget.printer.state.fanSpeed ?? 0).toDouble();
      _auxFanSpeed = (widget.printer.state.auxFanSpeed ?? 0).toDouble();
    });
  }

  @override
  void dispose() {
    widget.printer.removeListener(_updateSpeeds);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          _FanSlider(
            label: '模型风扇',
            value: _partFanSpeed,
            onChanged: (value) {
              setState(() => _partFanSpeed = value);
            },
            onChangeEnd: (value) async {
              await widget.printer.setPartFanSpeed(value.toInt());
            },
          ),
          const SizedBox(height: 16),
          _FanSlider(
            label: '辅助风扇',
            value: _auxFanSpeed,
            onChanged: (value) {
              setState(() => _auxFanSpeed = value);
            },
            onChangeEnd: (value) async {
              await widget.printer.setAuxFanSpeed(value.toInt());
            },
          ),
        ],
      ),
    );
  }
}

class _FanSlider extends StatelessWidget {
  const _FanSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: FitnessAppTheme.darkText,
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: FitnessAppTheme.nearlyDarkBlue,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: FitnessAppTheme.nearlyDarkBlue,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
