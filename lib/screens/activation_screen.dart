/// 激活码页面 — 用户输入激活码 / 查看激活状态 / 管理员生成码+列码
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _genCountCtrl = TextEditingController(text: '1');
  bool _loading = false;
  bool _checking = true;
  String? _error;
  String? _successMsg;

  // 激活状态
  bool _activated = false;
  DateTime? _activatedUntil;

  // 管理员
  bool _isAdmin = false;
  bool _adminLoading = false;
  String? _adminError;
  String? _adminSuccess;
  String _genType = 'trial'; // trial | month
  List<dynamic> _codes = [];

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _checkAdmin();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _genCountCtrl.dispose();
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

  Future<void> _checkAdmin() async {
    try {
      final me = await apiService.getMe();
      final admin = me['is_admin'] ?? false;
      if (mounted) {
        setState(() { _isAdmin = admin; });
        if (admin) {
          _loadCodes();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('管理员检查失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadCodes() async {
    setState(() { _adminLoading = true; _adminError = null; });
    try {
      final list = await apiService.listActivationCodes();
      if (mounted) setState(() { _codes = list; });
    } catch (e) {
      if (mounted) setState(() { _adminError = '加载码列表失败'; });
    } finally {
      if (mounted) setState(() { _adminLoading = false; });
    }
  }

  Future<void> _generateCodes() async {
    final countStr = _genCountCtrl.text.trim();
    final count = int.tryParse(countStr) ?? 1;
    if (count < 1 || count > 100) {
      setState(() { _adminError = '数量须 1-100'; });
      return;
    }

    setState(() { _adminLoading = true; _adminError = null; _adminSuccess = null; });
    try {
      final data = await apiService.generateCodes(_genType, count);
      final codes = data['codes'] as List? ?? [];
      final codeStrs = codes.map((c) => c.toString()).join('\n');
      if (mounted) {
        setState(() {
          _adminSuccess = '生成 ${codes.length} 个${_genType == 'trial' ? '试用' : '正式'}码：\n\n$codeStrs';
        });
        _loadCodes();
      }
    } catch (e) {
      String msg = '生成失败';
      final estr = e.toString();
      if (estr.contains('403')) {
        msg = '无权限：仅管理员可操作';
      }
      if (mounted) setState(() { _adminError = msg; });
    } finally {
      if (mounted) setState(() { _adminLoading = false; });
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
            onPressed: () { _checkStatus(); _checkAdmin(); },
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

              // ── 管理员区域 ──
              if (_isAdmin) ...[
                const SizedBox(height: 40),
                _buildAdminSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 管理员面板 ──
  Widget _buildAdminSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Color(0xFF60A5FA), size: 24),
              const SizedBox(width: 8),
              const Text(
                '管理员面板',
                style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF60A5FA)),
                onPressed: _loadCodes,
                tooltip: '刷新码列表',
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 24),

          // 生成码
          const Text(
            '生成激活码',
            style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // 类型选择
          Row(
            children: [
              Expanded(
                child: _typeButton('试用码 (+1天)', 'trial'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _typeButton('正式码 (+30天)', 'month'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 数量 + 生成按钮
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _genCountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '1',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _adminLoading ? null : _generateCodes,
                  icon: _adminLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_circle_outline, size: 20),
                  label: Text('生成 ${_genType == 'trial' ? '试用' : '正式'}码'),
                ),
              ),
            ],
          ),

          // 生成结果
          if (_adminSuccess != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF60A5FA), size: 18),
                      const SizedBox(width: 8),
                      const Text('生成成功', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFF60A5FA)),
                        onPressed: () {
                          // 复制到剪贴板
                          final text = _adminSuccess!.split('\n\n').last;
                          
                          Clipboard.setData(ClipboardData(text: text));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                            );
                          }
                        },
                        tooltip: '复制码',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _adminSuccess!,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontFamily: 'monospace', height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_adminError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_adminError!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],

          // 码列表
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                '已生成的激活码',
                style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('${_codes.length} 个', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),

          if (_codes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('暂无激活码', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ),
            )
          else
            ..._codes.map((c) => _buildCodeItem(c)),
        ],
      ),
    );
  }

  Widget _buildCodeItem(dynamic c) {
    final code = c['code'] ?? '';
    final type = c['type'] ?? '';
    final status = c['status'] ?? '';
    final usedBy = c['used_by'];

    final isUsed = status == 'used';
    final color = isUsed ? Colors.grey : const Color(0xFF60A5FA);
    final typeLabel = type == 'trial' ? '试用' : '正式';
    final statusLabel = isUsed ? '已使用' : '未使用';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  code,
                  style: TextStyle(
                    color: isUsed ? Colors.grey[500] : Colors.white,
                    fontSize: 14, fontFamily: 'monospace', letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isUsed ? Colors.grey : AppTheme.accent).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: isUsed ? Colors.grey[400] : AppTheme.accent,
                          fontSize: 11, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUsed && usedBy != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '用户: ${usedBy.toString().substring(0, 8)}...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: color,
            onPressed: () {
              
              Clipboard.setData(ClipboardData(text: code));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已复制: $code'), duration: const Duration(seconds: 1)),
                );
              }
            },
            tooltip: '复制',
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String label, String type) {
    final selected = _genType == type;
    return InkWell(
      onTap: () => setState(() { _genType = type; }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF60A5FA).withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF60A5FA)
                : const Color(0xFF334155),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFA0AEC0),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
