import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'ai_workspace_screen.dart';
import 'backtest_screen.dart';
import 'login_screen.dart';
import 'strategy_detail_screen.dart';
import 'settings_screen.dart';
import 'log_stream_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  final _backtestKey = GlobalKey<BacktestScreenState>();
  List<Strategy> _strategies = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStrategies();
  }

  Future<void> _loadStrategies() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await apiService.getStrategies();
      setState(() { _strategies = data; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _buildStrategyTab(),
          const AIWorkspaceScreen(),
          BacktestScreen(key: _backtestKey),
          const SettingsScreen(),
          const LogStreamScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) {
          // 切到回测 Tab 时强制重新拉取策略，避免 IndexedStack 缓存导致下拉为空
          if (i == 2) _backtestKey.currentState?.reloadStrategies();
          // 切回策略 Tab 时刷新列表（保存新策略后立即可见）
          if (i == 0) _loadStrategies();
          setState(() => _tab = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '策略'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'AI 工作台'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: '回测'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '设置'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: '日志'),
        ],
      ),
    );
  }

  Widget _buildStrategyTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能策略中枢'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStrategies,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 56, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        const Text(
                          '加载失败',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '可能是网络到服务器延迟偏高，点下方按钮重试。',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadStrategies,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : _strategies.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _strategies.length,
                      itemBuilder: (ctx, i) => _StrategyCard(
                        strategy: _strategies[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StrategyDetailScreen(
                              strategy: _strategies[i],
                              onRefresh: _loadStrategies,
                            ),
                          ),
                        ),
                        onStart: () => _toggleStrategy(_strategies[i], true),
                        onStop: () => _toggleStrategy(_strategies[i], false),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          const Text(
            '还没有策略',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '去 AI 工作台生成你的第一个策略',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() => _tab = 1),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text('AI 生成策略'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStrategy(Strategy s, bool start) async {
    try {
      if (start) {
        await apiService.startStrategy(s.id);
      } else {
        await apiService.stopStrategy(s.id);
      }
      await _loadStrategies();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── 策略卡片组件 ────────────────────────────────────────────
class _StrategyCard extends StatelessWidget {
  final Strategy strategy;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _StrategyCard({
    required this.strategy,
    required this.onTap,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = strategy.totalPnl;
    final pnlColor = pnl >= 0 ? AppTheme.accent : AppTheme.loss;
    final statusColor = _statusColor(strategy.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部行：名称 + 状态标签
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strategy.name,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      strategy.status.label,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 指标行
              Row(
                children: [
                  _MetricChip(
                    label: '盈亏',
                    value: '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)} USDT',
                    color: pnlColor,
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: '交易次数',
                    value: '${strategy.totalTrades}',
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: '胜率',
                    value: '${(strategy.winRate * 100).toStringAsFixed(1)}%',
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 底部操作按钮
              Row(
                children: [
                  // 查看
                  _ActionBtn(
                    icon: Icons.visibility_outlined,
                    label: '查看',
                    onTap: onTap,
                  ),
                  const SizedBox(width: 8),
                  // 启动/停止
                  if (strategy.status == StrategyStatus.running)
                    _ActionBtn(
                      icon: Icons.stop_circle_outlined,
                      label: '停止',
                      color: AppTheme.loss,
                      onTap: onStop,
                    )
                  else
                    _ActionBtn(
                      icon: Icons.play_circle_outline,
                      label: '启动',
                      color: AppTheme.accent,
                      onTap: onStart,
                    ),
                  const Spacer(),
                  // K线图占位
                  Container(
                    width: 48, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.show_chart, color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(StrategyStatus s) {
    switch (s) {
      case StrategyStatus.running: return AppTheme.accent;
      case StrategyStatus.paused: return Colors.orange;
      case StrategyStatus.error: return AppTheme.loss;
      default: return AppTheme.textSecondary;
    }
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon, required this.label,
    this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: c, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
