import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'strategy_detail_screen.dart';

class AIWorkspaceScreen extends ConsumerStatefulWidget {
  const AIWorkspaceScreen({super.key});

  @override
  ConsumerState<AIWorkspaceScreen> createState() => _AIWorkspaceScreenState();
}

class _AIWorkspaceScreenState extends ConsumerState<AIWorkspaceScreen> {
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: prompt));
      _loading = true;
    });
    _promptCtrl.clear();
    _scrollToBottom();

    try {
      final result = await apiService.generateStrategy(prompt);
      final dsl = result['dsl'] as Map<String, dynamic>;
      final explanation = result['explanation'] as String;

      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content: explanation,
          dsl: dsl,
        ));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: '生成失败: $e'));
        _loading = false;
      });
    }
  }

  Future<void> _saveStrategy(Map<String, dynamic> dsl) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final strategy = await apiService.createStrategy(
        name: 'AI策略 ${DateTime.now().millisecondsSinceEpoch % 10000}',
        description: '由 AI 自动生成',
        config: dsl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('策略已保存！'),
          backgroundColor: AppTheme.accent,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StrategyDetailScreen(
            strategy: strategy,
            onRefresh: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: AppTheme.loss),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setPrompt(String text) {
    setState(() {
      _promptCtrl.text = text;
    });
    _promptCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已填入: $text', style: const TextStyle(fontSize: 13)),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.cardBg,
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 策略工作台')),
      body: Column(
        children: [
          // 提示区
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'DeepSeek AI',
                      style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '用自然语言描述你的交易策略，AI 自动生成可执行的策略配置',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _HintChip('BTC 1d 止盈10%止损5%',
                        onTap: () => _setPrompt('BTC 日线，止盈 10%，止损 5%')),
                    _HintChip('ETH 4H 趋势策略',
                        onTap: () => _setPrompt('ETH 4 小时趋势跟踪策略')),
                    _HintChip('波段策略 持仓7天',
                        onTap: () => _setPrompt('波段策略，预期持仓周期 7 天')),
                    _HintChip('金叉买入 死叉卖出',
                        onTap: () => _setPrompt('均线金叉买入，死叉卖出')),
                  ],
                ),
              ],
            ),
          ),

          // 对话区
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      '说出你的策略想法...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: _messages[i],
                      saving: _saving,
                      onSave: (dsl) => _saveStrategy(dsl),
                    ),
                  ),
          ),

          // 输入区
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: '描述你的交易策略...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48, height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _generate,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _HintChip(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    );
  }
}

class _ChatMessage {
  final String role;      // user | assistant
  final String content;
  final Map<String, dynamic>? dsl;

  _ChatMessage({required this.role, required this.content, this.dsl});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool saving;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _MessageBubble({
    required this.message,
    this.saving = false,
    required this.onSave,
  });

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 14)),
            if (message.dsl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '策略配置预览',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: message.dsl == null || saving
                              ? null
                              : () => onSave(message.dsl!),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.primary),
                                )
                              : const Text('保存策略', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${message.dsl!['symbol']} · ${message.dsl!['timeframe']} · ${message.dsl!['entry']?['side'] ?? 'buy'}',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (message.dsl!['exit'] != null)
                      Text(
                        '止盈 +${message.dsl!['exit']['take_profit_pct']}% / 止损 -${message.dsl!['exit']['stop_loss_pct']}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
