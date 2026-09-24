/// 设置页面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../version.dart';
import 'activation_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _okxKeySet = false;
  bool _simulateMode = true;
  bool _activated = false;
  DateTime? _activatedUntil;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadActivationStatus();
  }

  Future<void> _loadActivationStatus() async {
    try {
      final data = await apiService.getActivationStatus();
      if (mounted) {
        setState(() {
          _activated = data['activated'] ?? false;
          final untilStr = data['activated_until'];
          if (untilStr != null) {
            _activatedUntil = DateTime.tryParse(untilStr.toString());
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    try {
      final status = await apiService.getOKXKeyStatus();
      setState(() {
        _okxKeySet = status['set'] ?? false;
        _simulateMode = status['mode'] == 'simulate';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // OKX 配置
          _SectionTitle('交易所'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key, color: AppTheme.primary),
                  title: const Text('OKX API Key', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _okxKeySet ? '已配置（实盘）' : '未配置',
                    style: TextStyle(color: _okxKeySet ? AppTheme.accent : Colors.grey[500]),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () => _showOKXKeyDialog(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.science_outlined, color: AppTheme.primary),
                  title: const Text('模拟盘模式', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('开启后使用 OKX 模拟盘资金', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: _simulateMode,
                  activeColor: AppTheme.accent,
                  onChanged: (v) async {
                    setState(() => _simulateMode = v);
                    await apiService.switchMode(v ? 'simulate' : 'live');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 激活状态
          _SectionTitle('授权'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _activated ? Icons.verified : Icons.gpp_bad,
                    color: _activated ? AppTheme.accent : AppTheme.loss,
                  ),
                  title: const Text('激活状态', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _activated
                        ? (_activatedUntil != null
                            ? '已激活 · 至 ${_formatDate(_activatedUntil!)}'
                            : '已激活')
                        : '未激活',
                    style: TextStyle(
                      color: _activated ? AppTheme.accent : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActivationScreen(navigateToHomeOnSuccess: false)),
                    ).then((_) => _loadActivationStatus());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 账户
          _SectionTitle('账户'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primary),
                  title: const Text('关于', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () => _showAbout(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.loss),
                  title: const Text('退出登录', style: TextStyle(color: AppTheme.loss)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('确认退出'),
                        content: const Text('确定要退出当前账户吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('退出', style: TextStyle(color: AppTheme.loss)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await apiService.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          ],
      ),
    );
  }

  void _showOKXKeyDialog() {
    final apiKeyCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final passphraseCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('配置 OKX API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: apiKeyCtrl,
              decoration: const InputDecoration(labelText: 'API Key'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: secretCtrl,
              decoration: const InputDecoration(labelText: 'Secret'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passphraseCtrl,
              decoration: const InputDecoration(labelText: 'Passphrase'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                await apiService.setOKXKey(
                  apiKeyCtrl.text, secretCtrl.text, passphraseCtrl.text,
                );
                Navigator.pop(context);
                await _loadStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('OKX Key 配置成功'), backgroundColor: AppTheme.accent),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('配置失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于 CryptoTrader'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: $kAppVersion (build $kAppBuild)',
              style: const TextStyle(fontSize: 14, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('功能模块：\n• AI 策略生成（DeepSeek）\n• 历史回测\n• 模拟盘 / 实盘交易\n• 实时行情监控',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
