/// Bambu Lab App - 应用配置 + 路由
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/theme_provider.dart';
import 'package:bambu_lab_app/providers/screen_saver_provider.dart';
import 'package:bambu_lab_app/screens/connect/connect_screen.dart';
import 'package:bambu_lab_app/screens/dashboard/dashboard_screen.dart';
import 'package:bambu_lab_app/screens/home/home_screen.dart';
import 'package:bambu_lab_app/screens/splash/splash_screen.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

class BambuLabApp extends StatelessWidget {
  const BambuLabApp({super.key});

  static final _router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/connect', builder: (_, __) => const ConnectScreen()),
      GoRoute(path: '/connect/:id',
          builder: (_, s) => ConnectScreen(editId: int.tryParse(s.pathParameters['id']!))),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeProvider>(
      builder: (_, tp, __) {
        final themeMode = tp.mode;
        return MaterialApp.router(
          title: 'Bambu Lab',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'NotoSansSC',
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF034C27), brightness: Brightness.light),
            scaffoldBackgroundColor: NeuoColors.light.background,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'NotoSansSC',
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF78), brightness: Brightness.dark),
            scaffoldBackgroundColor: NeuoColors.dark.background,
          ),
          themeMode: themeMode,
          routerConfig: _router,
          builder: (context, child) {
            final brightness = tp.resolveBrightness(context);
            return Consumer<ScreenSaverProvider>(
              builder: (_, ss, __) {
                return Listener(
                  onPointerDown: (_) => ss.resetTimer(),
                  onPointerMove: (_) => ss.resetTimer(),
                  child: Stack(
                    children: [
                      NeuoTheme(
                        colors: brightness == Brightness.dark ? NeuoColors.dark : NeuoColors.light,
                        child: SafeArea(
                          left: true, right: true, top: false, bottom: false,
                          // kiosk（Linux 竖屏输出）内容旋转 90° 呈现横屏：
                          // phoc 的 rotate 在 Adreno 306/freedreno 上不可靠
                          // （90° 半边黑、180° 崩溃）。RotatedBox 交换布局
                          // 约束，子内容按横屏尺寸布局，触摸命中自动跟随。
                          // 若画面上下颠倒，quarterTurns 改 3。
                          // 运行时开关：kiosk 服务里设 BAMBU_NO_ROTATE=1
                          // 可禁用旋转（排查黑屏/方向问题时用，无需重建）。
                          child: (Platform.isLinux &&
                                  Platform.environment['BAMBU_NO_ROTATE'] != '1')
                              ? RotatedBox(quarterTurns: 1, child: child!)
                              : child!,
                        ),
                      ),
                      if (ss.isActive)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => ss.resetTimer(),
                            behavior: HitTestBehavior.opaque,
                            child: const ColoredBox(color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
