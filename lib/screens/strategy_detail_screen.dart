import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class StrategyDetailScreen extends ConsumerStatefulWidget {
  final Strategy strategy;
  final VoidCallback onRefresh;

  const StrategyDetailScreen({
    super.key,
    required this.strategy,
    required this.onRefresh,
  });

  @override
  ConsumerState<StrategyDetailScreen> createState() => _StrategyDetailScreenState();
}

class _StrategyDetailScreenState extends ConsumerState<StrategyDetailScreen> {
  late Strategy _strategy;

  @override
  void initState() {
    super.initState();
    _strategy = widget.strategy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_strategy.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('删除后无法恢复，确定要删除此策略吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await apiService.deleteStrategy(_strategy.id);
                  widget.onRefresh();
                  if (mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('删除策略', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态 + 盈亏卡片
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    title: '累计盈亏',
                    value: '${_strategy.totalPnl >= 0 ? '+' : ''}${_strategy.totalPnl.toStringAsFixed(2)}',
                    unit: 'USDT',
                    color: _strategy.totalPnl >= 0 ? AppTheme.accent : AppTheme.loss,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    title: '胜率',
                    value: '${(_strategy.winRate * 100).toStringAsFixed(1)}',
                    unit: '%',
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    title: '交易次数',
                    value: '${_strategy.totalTrades}',
                    unit: '次',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    title: '状态',
                    value: _strategy.status.label,
                    unit: '',
                    color: _strategy.status == StrategyStatus.running
                        ? AppTheme.accent : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 策略配置
            const Text('策略配置', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _ConfigSection(
              title: '市场',
              rows: [
                _ConfigRow('交易对', _strategy.config.symbol),
                _ConfigRow('周期', _strategy.config.timeframe),
              ],
            ),
            _ConfigSection(
              title: '入场',
              rows: [
                _ConfigRow('类型', _strategy.config.entry.type == 'scheduled' ? '定时入场' : '信号入场'),
                _ConfigRow('方向', _strategy.config.entry.side == 'buy' ? '买入 (Long)' : '卖出 (Short)'),
                _ConfigRow('资金占比', '${_strategy.config.entry.amountPct}%'),
                if (_strategy.config.entry.time != null)
                  _ConfigRow('执行时间', _strategy.config.entry.time!),
              ],
            ),
            _ConfigSection(
              title: '出场',
              rows: [
                _ConfigRow('止盈', '+${_strategy.config.exit.takeProfitPct}%'),
                _ConfigRow('止损', '-${_strategy.config.exit.stopLossPct}%'),
                _ConfigRow('最大持仓', '${_strategy.config.exit.maxHoldDays} 天'),
              ],
            ),
            _ConfigSection(
              title: '风控',
              rows: [
                _ConfigRow('最大持仓占比', '${_strategy.config.risk.maxPositionPct}%'),
                _ConfigRow('日亏损限额', '-${_strategy.config.risk.dailyLossLimitPct}%'),
                _ConfigRow('最大回撤', '-${_strategy.config.risk.maxDrawdownPct}%'),
              ],
            ),
            const SizedBox(height: 32),

            // 操作按钮
            if (_strategy.status == StrategyStatus.running)
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _toggleStrategy(false),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.loss),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('停止策略'),
                ),
              )
            else
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _toggleStrategy(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('启动策略'),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: 导航到回测
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.border),
                ),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('回测策略'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStrategy(bool start) async {
    try {
      if (start) {
        await apiService.startStrategy(_strategy.id);
      } else {
        await apiService.stopStrategy(_strategy.id);
      }
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;

  const _InfoCard({required this.title, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(unit, style: TextStyle(color: color, fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  final String title;
  final List<_ConfigRow> rows;

  const _ConfigSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  Text(r.value, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ConfigRow {
  final String label;
  final String value;
  _ConfigRow(this.label, this.value);
}
