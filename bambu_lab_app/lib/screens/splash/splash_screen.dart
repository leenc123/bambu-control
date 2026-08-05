/// 开屏页 — Logo 图片 → App 名称淡入 → 进入主页
///
/// 注意：已移除 Lottie 动画。postmarketOS (musl) 上 Dart VM 栈误判，
/// 首帧树越深越容易 Stack Overflow；Lottie 的 126KB JSON 首帧解码
/// 是压垮栈的最后一根稻草。改用静态图片后首帧树显著变浅。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// 控制文字淡入 + 上滑
  late final AnimationController _textController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();

    // 静态 logo：无 Lottie JSON 解码，首帧树浅，规避 musl 栈误判
    // 短暂停留后开始文字动画（原 Lottie 播放时序的近似）
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _startTextAnimation();
    });

    // ---------- 文字入场控制器 ----------
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _titleFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _subFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
    );
    _subSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // 文字动画结束后，稍等片刻再跳转
    _textController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.go('/');
        });
      }
    });
  }

  void _startTextAnimation() {
    _textController.forward();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // 版本信息获取失败不影响启动
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Logo（静态图片，无 Lottie 解码） ----
                Image.asset(
                  'bamboo_app_logo.png',
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 40),
                // ---- App 名称（动画结束后淡入） ----
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: Text(
                      'Bambu Lab',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SlideTransition(
                  position: _subSlide,
                  child: FadeTransition(
                    opacity: _subFade,
                    child: Text(
                      '3D Printer Control',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: c.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ---- 版本号 ----
          Positioned(
            left: 0, right: 0, bottom: 32,
            child: Center(
              child: Text(
                _version.isNotEmpty ? 'v$_version' : '',
                style: TextStyle(
                  fontSize: 11,
                  color: c.textSecondary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
