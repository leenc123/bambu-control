/// AMS 耗材管理 - 显示 AMSHub 中每个 AMS 单元的耗材信息
library;

import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/models/ams.dart';
import 'package:bambu_lab_app/models/filament_tray.dart';
import 'package:bambu_lab_app/providers/ams_provider.dart';

class AmsScreen extends StatelessWidget {
  const AmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AMS 耗材')),
      body: Consumer<AmsProvider>(
        builder: (context, amsProvider, _) {
          if (!amsProvider.hasAms) {
            return const _NoAmsView();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry
                    in amsProvider.hub.amsHub.entries) ...[
                  _AmsUnitCard(
                    index: entry.key,
                    ams: entry.value,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.home,
              label: '主页',
              onTap: () => context.go('/'),
            ),
            _NavButton(
              icon: Icons.tune,
              label: '高级',
              onTap: () => context.push('/control'),
            ),
            _NavButton(
              icon: Icons.inventory_2,
              label: 'AMS',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _AmsUnitCard extends StatelessWidget {
  const _AmsUnitCard({required this.index, required this.ams});

  final int index;
  final AMS ams;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
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
            // AMS 标题行
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: FitnessAppTheme.nearlyDarkBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'AMS #${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FitnessAppTheme.darkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 湿度和温度信息
            Row(
              children: [
                _InfoChip(
                  icon: Icons.water_drop,
                  label: '湿度',
                  value: '${ams.humidity}% (${ams.humidityDescription})',
                  color: _humidityColor(ams.humidity),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.thermostat,
                  label: '温度',
                  value: '${ams.temperature.toStringAsFixed(1)}°C',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 料盘列表
            if (ams.filamentTrays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '无耗材信息',
                  style: TextStyle(
                    fontSize: 14,
                    color: FitnessAppTheme.grey,
                  ),
                ),
              )
            else
              ...ams.filamentTrays.entries.map(
                (tray) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FilamentTrayTile(
                    slotIndex: tray.key,
                    tray: tray.value,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _humidityColor(int humidity) {
    if (humidity <= 20) return Colors.green;
    if (humidity <= 40) return Colors.blue;
    if (humidity <= 60) return Colors.orange;
    return Colors.red;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: FitnessAppTheme.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilamentTrayTile extends StatelessWidget {
  const _FilamentTrayTile({required this.slotIndex, required this.tray});

  final int slotIndex;
  final FilamentTray tray;

  @override
  Widget build(BuildContext context) {
    final trayColor = _parseColor(tray.displayColor);
    final hasFilament = tray.trayType.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FitnessAppTheme.nearlyWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 颜色圆点
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hasFilament
                  ? (trayColor ?? FitnessAppTheme.grey)
                  : FitnessAppTheme.nearlyWhite,
              shape: BoxShape.circle,
              border: Border.all(
                color: FitnessAppTheme.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 耗材信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${slotIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FitnessAppTheme.nearlyDarkBlue,
                      ),
                    ),
                    if (tray.trayType.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        tray.trayType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: FitnessAppTheme.darkText,
                        ),
                      ),
                    ],
                  ],
                ),
                if (tray.traySubBrands.isNotEmpty)
                  Text(
                    tray.traySubBrands,
                    style: TextStyle(
                      fontSize: 11,
                      color: FitnessAppTheme.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // 喷嘴温度范围
          if (tray.nozzleTempMax > 0)
            Text(
              '${tray.nozzleTempMin}-${tray.nozzleTempMax}°C',
              style: TextStyle(
                fontSize: 11,
                color: FitnessAppTheme.grey,
              ),
            ),
        ],
      ),
    );
  }

  Color? _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      return null;
    } on FormatException {
      return null;
    }
  }
}

class _NoAmsView extends StatelessWidget {
  const _NoAmsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text('未检测到 AMS'),
          const SizedBox(height: 4),
          Text(
            '请确保 AMS 已连接打印机',
            style: TextStyle(
              fontSize: 14,
              color: FitnessAppTheme.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FitnessAppTheme.nearlyDarkBlue),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: FitnessAppTheme.nearlyDarkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
