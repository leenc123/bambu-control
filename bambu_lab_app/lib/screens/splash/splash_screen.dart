/// 开屏页 — Lottie Logo 动画 → App 名称淡入 → 进入主页
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// 控制 Lottie Logo 动画
  late final AnimationController _lottieController;

  /// 控制文字淡入 + 上滑
  late final AnimationController _textController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;
  String _version = '';

  /// 兜底定时器：Lottie 加载/播放卡住时强制进入文字动画
  Timer? _lottieFallbackTimer;

  @override
  void initState() {
    super.initState();
    _loadVersion();

    // ---------- Lottie 控制器 ----------
    _lottieController = AnimationController(vsync: this);
    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _lottieFallbackTimer?.cancel();
        _startTextAnimation();
      }
    });

    // 兜底：如果 Lottie 的 onLoaded 一直不触发（解码失败等），
    // 3 秒后强制进入文字动画，避免永远卡在开屏页（白屏）
    _lottieFallbackTimer = Timer(const Duration(seconds: 3), () {
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
    _lottieFallbackTimer?.cancel();
    _lottieController.dispose();
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
                // ---- Logo 动画（小尺寸） ----
                // 解码失败时降级为静态 logo，不阻塞导航
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Lottie.asset(
                    'assets/bambu_control.json',
                    controller: _lottieController,
                    repeat: false,
                    errorBuilder: (_, __, ___) {
                      // Lottie 解码失败：直接开始文字动画，不阻塞导航
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _startTextAnimation();
                      });
                      return Image.asset(
                        'bamboo_app_logo.png',
                        width: 140,
                        height: 140,
                      );
                    },
                    onLoaded: (composition) {
                      _lottieController.duration = composition.duration;
                      _lottieController.forward();
                    },
                  ),
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
