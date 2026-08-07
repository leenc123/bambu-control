/// Bambu Lab App - 入口文件
library;

import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/app.dart';
import 'package:bambu_lab_app/db/database.dart';
import 'package:bambu_lab_app/providers/ai_monitor_provider.dart';
import 'package:bambu_lab_app/providers/ams_provider.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/providers/theme_provider.dart';
import 'package:bambu_lab_app/providers/screen_saver_provider.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';
import 'package:flutter/services.dart';

/// 将未捕获的 Flutter/Dart 错误写入本地文件（排查白屏/黑屏用）
///
/// 日志位置: $HOME/bambu_lab_app_crash.log
/// 只写文件 + 简单打印，不做栈解析 —— 之前 stack overflow 时
/// 错误报告的栈解析本身级联崩溃，把真正的根因刷没了。
void _installCrashLog() {
  final logFile = File(
    '${Platform.environment['HOME'] ?? '/tmp'}/bambu_lab_app_crash.log',
  );

  void write(Object error, StackTrace? stack) {
    try {
      logFile.writeAsStringSync(
        '${DateTime.now().toIso8601String()}\n$error\n$stack\n'
        '${'-' * 60}\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // 写日志失败则忽略（例如磁盘满）
    }
  }

  FlutterError.onError = (details) {
    write(details.exception, details.stack);
    debugPrint('CRASH: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    write(error, stack);
    debugPrint('CRASH: $error');
    // 吞掉未处理异步错误，防止整个 isolate 崩溃导致黑屏
    return true;
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 白屏/黑屏排查：首个未捕获异常先落盘，避免级联刷屏
  _installCrashLog();

  final database = AppDatabase();
  DebugLog.setDatabase(database);
  DebugLog.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // 完全隐藏状态栏 + 导航栏（沉浸式），适配挖孔屏
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: const []);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final configProvider = PrinterConfigProvider(database);
  final printerProvider = PrinterProvider();
  final amsProvider = AmsProvider(printerProvider);

  // 启动初始化容错：DB/日志任何一步失败都不能阻止 UI 启动（避免黑屏）
  try {
    await configProvider.loadPrinters();
    // 从数据库加载历史日志
    await DebugLog.loadFromDb();
  } catch (e, st) {
    // 数据库不可用时继续启动：先显示 UI，后续操作会重新尝试
    debugPrint('启动初始化失败（继续启动 UI）: $e\n$st');
  }

  // runApp 后重新设置全屏（部分 ROM 会重置）
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: const []); // 彻底不显示任何系统栏
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
  });

  // 调试：kiosk 旋转开关状态（BAMBU_NO_ROTATE=1 时禁用旋转）
  debugPrint(
      'KIOSK: rotate=${Platform.isLinux && Platform.environment['BAMBU_NO_ROTATE'] != '1'}');

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<PrinterConfigProvider>.value(
          value: configProvider,
        ),
        ChangeNotifierProvider<PrinterProvider>.value(
          value: printerProvider,
        ),
        ChangeNotifierProvider<AmsProvider>.value(value: amsProvider),
        ChangeNotifierProvider<AiMonitorProvider>(
          create: (_) => AiMonitorProvider(printerProvider, configProvider),
        ),
        ChangeNotifierProvider<ThemeModeProvider>(
          create: (_) => ThemeModeProvider(),
        ),
        ChangeNotifierProvider<ScreenSaverProvider>(
          create: (_) => ScreenSaverProvider(),
        ),
      ],
      child: const BambuLabApp(),
    ),
  );
}
