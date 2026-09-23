"""
闪屏页 — 检查 token + 激活状态，决定跳转目标
"""
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import 'activation_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await apiService.restoreToken();

    // 简单延迟确保动画
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // 检查是否有 token
    final hasToken = apiService._dio.options.headers['Authorization'] != null;
    if (!hasToken) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // 有 token，检查激活状态
    try {
      final status = await apiService.getActivationStatus();
      final activated = status['activated'] ?? false;
      if (!mounted) return;

      if (!activated) {
        // 未激活 → 跳激活页
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
      } else {
        // 已激活 → 跳主页
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (_) {
      // 激活状态查询失败（可能 token 过期），跳登录
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_graph, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'CryptoTrader',
              style: TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI 量化交易平台',
              style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 15),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF1E88E5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
