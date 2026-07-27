/// 打印进度卡片 - 渐变背景显示打印状态和进度
library;


import 'package:flutter/material.dart';

import 'package:bambu_lab_app/models/print_status.dart';

class PrintProgressCard extends StatelessWidget {
  const PrintProgressCard({
    super.key,
    required this.printStatus,
    required this.printPercentage,
    required this.remainingTime,
  });

  final PrintStatus printStatus;
  final int? printPercentage;
  final String remainingTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 18),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2633C5),
              Color(0xFF6F56E8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8.0),
            bottomLeft: Radius.circular(8.0),
            bottomRight: Radius.circular(8.0),
            topRight: Radius.circular(68.0),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0xFF3A5160),
              offset: Offset(1.1, 1.1),
              blurRadius: 10.0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '打印任务',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                printStatus.displayName,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.timer,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    remainingTime,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (printPercentage != null) ...[
                    Icon(
                      Icons.percent,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$printPercentage%',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0xFF213333).withValues(alpha:0.4),
                          offset: const Offset(8.0, 8.0),
                          blurRadius: 8.0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.arrow_right,
                        color: const Color(0xFF6F56E8),
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
              if (printPercentage != null) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: printPercentage! / 100.0,
                  backgroundColor: Colors.white.withValues(alpha:0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
