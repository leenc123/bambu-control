/// Bambu Lab App - 应用配置 + 路由
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/theme_provider.dart';
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
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF034C27), brightness: Brightness.light),
            scaffoldBackgroundColor: NeuoColors.light.background,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF78), brightness: Brightness.dark),
            scaffoldBackgroundColor: NeuoColors.dark.background,
          ),
          themeMode: themeMode,
          routerConfig: _router,
          builder: (context, child) {
            final brightness = tp.resolveBrightness(context);
            return NeuoTheme(
              colors: brightness == Brightness.dark ? NeuoColors.dark : NeuoColors.light,
              child: SafeArea(
                left: true, right: true, top: false, bottom: false,
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}
