"""
激活码页面 — 用户输入激活码 / 查看激活状态
"""
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  final bool navigateToHomeOnSuccess;

  const ActivationScreen({super.key, this.navigateToHomeOnSuccess = true});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _checking = true;
  String? _error;
  String? _successMsg;

  // 激活状态
  bool _activated = false;
  DateTime? _activatedUntil;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() { _checking = true; _error = null; });
    try {
      final data = await apiService.getActivationStatus();
      _activated = data['activated'] ?? false;
      final untilStr = data['activated_until'];
      if (untilStr != null) {
        _activatedUntil = DateTime.tryParse(untilStr.toString());
      }
    } catch (_) {
      // 静默处理
    } finally {
      if (mounted) setState(() { _checking = false; });
    }
  }

  Future<void> _activate() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() { _error = '请输入激活码'; });
      return;
    }

    setState(() { _loading = true; _error = null; _successMsg = null; });
    try {
      final data = await apiService.activate(code);
      final activated = data['activated'] ?? false;
      final untilStr = data['activated_until'];
      final type = data['type'] ?? '';

      String msg = '激活成功！';
      if (untilStr != null) {
        final until = DateTime.tryParse(untilStr.toString());
        if (until != null) {
          _activatedUntil = until;
          _activated = true;
          final days = until.difference(DateTime.now()).inDays;
          final hours = until.difference(DateTime.now()).inHours;
          msg = '激活成功！${type == 'trial' ? '试用' : '正式'}版';
          if (days > 0) {
            msg += '，有效期剩余 $days 天';
          } else if (hours > 0) {
            msg += '，有效期剩余 $hours 小时';
          }
        }
      }
      setState(() { _successMsg = msg; _loading = false; });

      // 延迟跳转
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (widget.navigateToHomeOnSuccess) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      String errMsg = '激活失败';
      final errStr = e.toString();
      if (errStr.contains('404')) {
        errMsg = '激活码不存在';
      } else if (errStr.contains('400')) {
        if (errStr.contains('已被使用')) {
          errMsg = '激活码已被使用';
        } else if (errStr.contains('已过期')) {
          errMsg = '激活码已过期';
        } else {
          errMsg = '激活码无效';
        }
      } else if (errStr.contains('403')) {
        errMsg = '无权限操作';
      }
      setState(() { _error = errMsg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text('激活码'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 状态卡片
              _buildStatusCard(),
              const SizedBox(height: 32),

              // 输入区
              if (!_activated || _successMsg != null) ...[
                const Text(
                  '输入激活码',
                  style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '输入管理员分配的激活码以开通使用权限',
                  style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _codeCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'CT-XXXX-XXXX-XXXX-XXXX',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16, letterSpacing: 1),
                    prefixIcon: const Icon(Icons.card_giftcard),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _activate(),
                ),
                const SizedBox(height: 20),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14))),
                      ],
                    ),
                  ),

                if (_successMsg != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_successMsg!, style: TextStyle(color: AppTheme.accent, fontSize: 14))),
                      ],
                    ),
                  ),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _activate,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('激活'),
                  ),
                ),
              ],

              // 已激活但不是从 success 跳转来的
              if (_activated && _successMsg == null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.verified, color: AppTheme.accent, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        '已激活',
                        style: TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_activatedUntil != null)
                        Text(
                          '有效期至: ${_formatDate(_activatedUntil!)}',
                          style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('进入主页'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_checking) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final isActive = _activated && (_activatedUntil?.isAfter(DateTime.now()) ?? false);
    final color = isActive ? AppTheme.accent : AppTheme.loss;
    final statusText = isActive ? '已激活' : '未激活';
    final icon = isActive ? Icons.verified : Icons.gpp_bad;

    String? expiryText;
    if (_activatedUntil != null) {
      final now = DateTime.now();
      if (_activatedUntil!.isAfter(now)) {
        final days = _activatedUntil!.difference(now).inDays;
        final hours = _activatedUntil!.difference(now).inHours;
        expiryText = days > 0 ? '剩余 $days 天' : '剩余 $hours 小时';
      } else {
        expiryText = '已过期';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                if (expiryText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$expiryText · 到期: ${_formatDate(_activatedUntil!)}',
                    style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
