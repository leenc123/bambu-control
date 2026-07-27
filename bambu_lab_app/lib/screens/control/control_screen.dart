/// 高级打印控制 - G-code 终端、速度、温度、归位
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_provider.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级控制'),
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, printer, _) {
          if (!printer.isConnected) {
            return const _DisconnectedView();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 速度控制
                const _SectionHeader(title: '打印速度', subtitle: '模式'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _SpeedSelector(printer: printer),
                ),
                const SizedBox(height: 24),

                // 温度设置
                const _SectionHeader(title: '温度设置', subtitle: '目标'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _TemperatureInputs(printer: printer),
                ),
                const SizedBox(height: 24),

                // 归位和校准
                const _SectionHeader(title: '操作', subtitle: '校准'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _ActionButtons(printer: printer),
                ),
                const SizedBox(height: 24),

                // G-code 终端
                const _SectionHeader(title: 'G-code', subtitle: '终端'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GcodeTerminal(printer: printer),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            _NavButton(
              icon: Icons.home,
              label: '主页',
              onTap: () => context.go('/'),
            ),
            _NavButton(
              icon: Icons.tune,
              label: '高级',
              onTap: () {},
            ),
            _NavButton(
              icon: Icons.inventory_2,
              label: 'AMS',
              onTap: () => context.push('/ams'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.printer});

  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    const levels = [
      (label: '静音', level: 1, icon: Icons.snooze),
      (label: '标准', level: 2, icon: Icons.speed),
      (label: '运动', level: 3, icon: Icons.directions_run),
      (label: '狂暴', level: 4, icon: Icons.bolt),
    ];

    final currentSpeed = printer.state.printSpeed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3A5160).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: levels.map((item) {
          final isSelected = currentSpeed == item.level;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () async {
                  await printer.setPrintSpeed(item.level);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? Color(0xFF2633C5)
                      : Color(0xFFFAFAFA),
                  foregroundColor: isSelected
                      ? Colors.white
                      : Color(0xFF253840),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TemperatureInputs extends StatefulWidget {
  const _TemperatureInputs({required this.printer});

  final PrinterProvider printer;

  @override
  State<_TemperatureInputs> createState() => _TemperatureInputsState();
}

class _TemperatureInputsState extends State<_TemperatureInputs> {
  final _bedController = TextEditingController();
  final _nozzleController = TextEditingController();

  @override
  void dispose() {
    _bedController.dispose();
    _nozzleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3A5160).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _TempInputRow(
            label: '热床温度',
            icon: Icons.grid_view,
            controller: _bedController,
            hint: '60',
            unit: '°C',
            onSet: (temp) async {
              await widget.printer.setBedTemperature(temp);
            },
          ),
          const Divider(height: 24),
          _TempInputRow(
            label: '喷嘴温度',
            icon: Icons.whatshot,
            controller: _nozzleController,
            hint: '220',
            unit: '°C',
            onSet: (temp) async {
              await widget.printer.setNozzleTemperature(temp);
            },
          ),
        ],
      ),
    );
  }
}

class _TempInputRow extends StatelessWidget {
  const _TempInputRow({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    required this.unit,
    required this.onSet,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final String unit;
  final Future<void> Function(int temp) onSet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF2633C5), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF253840),
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14),
              filled: true,
              fillColor: Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 4),
        Text(unit, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            final temp = int.tryParse(controller.text.trim());
            if (temp != null && temp > 0) {
              onSet(temp);
              controller.clear();
            }
          },
          icon: const Icon(Icons.check_circle, size: 28),
          color: Color(0xFF2633C5),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.printer});

  final PrinterProvider printer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3A5160).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: '自动归位',
              icon: Icons.home_work,
              color: Color(0xFF2633C5),
              onTap: () async {
                await printer.autoHome();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: '刷新状态',
              icon: Icons.refresh,
              color: Colors.green,
              onTap: () {
                printer.pushAll();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GcodeTerminal extends StatefulWidget {
  const _GcodeTerminal({required this.printer});

  final PrinterProvider printer;

  @override
  State<_GcodeTerminal> createState() => _GcodeTerminalState();
}

class _GcodeTerminalState extends State<_GcodeTerminal> {
  final _controller = TextEditingController();
  final List<_GcodeEntry> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3A5160).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 历史记录
          if (_history.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final entry = _history[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '> ${entry.command}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: entry.success
                            ? Color(0xFF253840)
                            : Colors.red,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 输入行
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '输入 G-code (如 G28)',
                    filled: true,
                    fillColor: Color(0xFFFAFAFA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  onSubmitted: _sendCommand,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _sendCommand(_controller.text),
                icon: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendCommand(String command) async {
    final cmd = command.trim();
    if (cmd.isEmpty) return;

    final success = await widget.printer.sendGcode(cmd);
    setState(() {
      _history.add(_GcodeEntry(command: cmd, success: success));
    });
    _controller.clear();
  }
}

class _GcodeEntry {
  const _GcodeEntry({required this.command, required this.success});

  final String command;
  final bool success;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
                fontSize: 18,
                letterSpacing: 0.5,
                color: Color(0xFF4A6572),
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.normal,
              fontSize: 16,
              letterSpacing: 0.5,
              color: Color(0xFF2633C5),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Color(0xFF2633C5), size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2633C5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisconnectedView extends StatelessWidget {
  const _DisconnectedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 80,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text('未连接到打印机'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('返回主页'),
          ),
        ],
      ),
    );
  }
}
