"""
登录/注册页
"""
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import 'activation_screen.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      if (_isLogin) {
        await apiService.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await apiService.register(_usernameCtrl.text.trim(), _passwordCtrl.text);
      }
      if (!mounted) return;

      // 登录/注册成功后检查激活状态
      try {
        final status = await apiService.getActivationStatus();
        final activated = status['activated'] ?? false;
        if (!mounted) return;
        if (!activated) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ActivationScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } catch (_) {
        // 激活状态查询失败，默认进激活页
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivationScreen()),
        );
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo
                Container(
                  width: 72, height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.auto_graph, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? '欢迎回来' : '创建账户',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? '登录以继续使用 CryptoTrader' : '注册后即可开始 AI 量化交易',
                  style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // 用户名
                TextFormField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.length < 3)
                      ? '用户名至少 3 个字符' : null,
                ),
                const SizedBox(height: 16),

                // 密码
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? '密码至少 6 个字符' : null,
                ),
                const SizedBox(height: 24),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                if (_error != null) const SizedBox(height: 16),

                // 提交按钮
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isLogin ? '登录' : '注册'),
                  ),
                ),
                const SizedBox(height: 16),

                // 切换登录/注册
                TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _error = null;
                  }),
                  child: Text(
                    _isLogin ? '没有账户？立即注册' : '已有账户？登录',
                    style: const TextStyle(color: Color(0xFF1E88E5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
