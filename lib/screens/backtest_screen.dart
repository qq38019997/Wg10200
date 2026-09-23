import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BacktestScreen extends ConsumerStatefulWidget {
  const BacktestScreen({super.key});

  @override
  ConsumerState<BacktestScreen> createState() => BacktestScreenState();
}

class BacktestScreenState extends ConsumerState<BacktestScreen> {
  List<Strategy> _strategies = [];
  Strategy? _selectedStrategy;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();
  double _initialBalance = 10000;
  bool _loadingStrategies = true;
  bool _runningBacktest = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadStrategies();
  }

  /// 供首页 BottomNavigationBar 在切到回测 Tab 时主动调用，
  /// 解决 IndexedStack 缓存导致下拉策略列表为空的问题。
  void reloadStrategies() => _loadStrategies();

  Future<void> _loadStrategies() async {
    try {
      final data = await apiService.getStrategies();
      if (!mounted) return;
      setState(() {
        _strategies = data;
        _loadingStrategies = false;
        if (_selectedStrategy == null && data.isNotEmpty) {
          _selectedStrategy = data.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStrategies = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('策略加载失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _runBacktest() async {
    if (_selectedStrategy == null) return;
    setState(() { _runningBacktest = true; _result = null; });

    try {
      final result = await apiService.runBacktest(
        strategyId: _selectedStrategy!.id,
        startDate: _startDate,
        endDate: _endDate,
        initialBalance: _initialBalance,
      );
      setState(() { _result = result; _runningBacktest = false; });
    } catch (e) {
      setState(() => _runningBacktest = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回测失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('策略回测')),
      body: _loadingStrategies
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 策略选择
                  const Text('选择策略', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButton<Strategy>(
                        value: _selectedStrategy,
                        isExpanded: true,
                        dropdownColor: AppTheme.cardBg,
                        underline: const SizedBox(),
                        items: _strategies.map((s) => DropdownMenuItem(
                          value: s, child: Text(s.name, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedStrategy = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 日期范围
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: '开始日期',
                          date: _startDate,
                          onChanged: (d) => setState(() => _startDate = d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: '结束日期',
                          date: _endDate,
                          onChanged: (d) => setState(() => _endDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 初始资金
                  const Text('初始资金 (USDT)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      suffixText: 'USDT',
                    ),
                    controller: TextEditingController(text: _initialBalance.toStringAsFixed(0)),
                    onChanged: (v) => setState(() => _initialBalance = double.tryParse(v) ?? 10000),
                  ),
                  const SizedBox(height: 24),

                  // 运行按钮
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _runningBacktest ? null : _runBacktest,
                      icon: _runningBacktest
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_runningBacktest ? '回测运行中...' : '开始回测'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 回测结果
                  if (_result != null) _buildResult(_result!),
                ],
              ),
            ),
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    final totalReturn = (result['total_return'] as num).toDouble();
    final finalBalance = (result['final_balance'] as num).toDouble();
    final initialBalance = (result['initial_balance'] as num).toDouble();
    final maxDrawdown = (result['max_drawdown'] as num).toDouble();
    final sharpeRatio = (result['sharpe_ratio'] as num).toDouble();
    final winRate = (result['win_rate'] as num).toDouble();
    final totalTrades = result['total_trades'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('回测结果', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        // 收益率大字
        Card(
          color: totalReturn >= 0
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.loss.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${totalReturn >= 0 ? '+' : ''}${totalReturn.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: totalReturn >= 0 ? AppTheme.accent : AppTheme.loss,
                    fontSize: 36, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$initialBalance → ${finalBalance.toStringAsFixed(2)} USDT',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 指标网格
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _MetricCard('夏普比率', '${sharpeRatio.toStringAsFixed(2)}', sharpeRatio > 1 ? AppTheme.accent : Colors.orange),
            _MetricCard('最大回撤', '${maxDrawdown.toStringAsFixed(2)}%', AppTheme.loss),
            _MetricCard('胜率', '${(winRate * 100).toStringAsFixed(1)}%', AppTheme.primary),
            _MetricCard('交易次数', '$totalTrades 次', Colors.white),
          ],
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({required this.label, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (_, child) => Theme(data: ThemeData.dark(), child: child!),
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(height: 4),
              Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
