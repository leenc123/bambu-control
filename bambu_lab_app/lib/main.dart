/// Bambu Lab App - 入口文件
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/app.dart';
import 'package:bambu_lab_app/db/database.dart';
import 'package:bambu_lab_app/providers/ams_provider.dart';
import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/providers/printer_provider.dart';
import 'package:bambu_lab_app/providers/theme_provider.dart';
import 'package:bambu_lab_app/providers/screen_saver_provider.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
