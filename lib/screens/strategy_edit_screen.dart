import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class StrategyEditScreen extends StatefulWidget {
  final Strategy strategy;
  final VoidCallback onSaved;

  const StrategyEditScreen({super.key, required this.strategy, required this.onSaved});

  @override
  State<StrategyEditScreen> createState() => _StrategyEditScreenState();
}

class _StrategyEditScreenState extends State<StrategyEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late String _side;
  late double _leverage;
  late int _amountPct;
  late String _entryType;
  late TextEditingController _entryTimeController;
  late double _takeProfitPct;
  late double _stopLossPct;
  late int _maxHoldDays;
  late bool _trailingStop;
  late int _maxPositionPct;
  late double _dailyLossLimitPct;
  late double _maxDrawdownPct;
  late bool _useFundingRateDefault;
  late TextEditingController _fundingRateController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.strategy.config;
    _nameController = TextEditingController(text: widget.strategy.name);
    _descController = TextEditingController(text: widget.strategy.description ?? '');
    _side = c.entry.side;
    _leverage = c.entry.leverage;
    _amountPct = c.entry.amountPct;
    _entryType = c.entry.type;
    _entryTimeController = TextEditingController(text: c.entry.time ?? '00:05 UTC');
    _takeProfitPct = c.exit.takeProfitPct;
    _stopLossPct = c.exit.stopLossPct;
    _maxHoldDays = c.exit.maxHoldDays;
    _trailingStop = c.exit.trailingStop;
    _maxPositionPct = c.risk.maxPositionPct;
    _dailyLossLimitPct = c.risk.dailyLossLimitPct;
    _maxDrawdownPct = c.risk.maxDrawdownPct;
    final fr = c.fundingRateOverride;
    _useFundingRateDefault = fr == null;
    _fundingRateController = TextEditingController(
      text: fr != null ? fr.toString() : '0.0001',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _entryTimeController.dispose();
    _fundingRateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _snack('策略名称不能为空');
      return;
    }
    if (_leverage < 1 || _leverage > 125) {
      _snack('杠杆倍数必须在 1~125 之间');
      return;
    }
    if (_takeProfitPct <= 0 || _takeProfitPct > 100) {
      _snack('止盈比例必须在 0.1%~100% 之间');
      return;
    }
    if (_stopLossPct <= 0 || _stopLossPct > 50) {
      _snack('止损比例必须在 0.1%~50% 之间');
      return;
    }
    if (_dailyLossLimitPct <= 0 || _dailyLossLimitPct > 20) {
      _snack('日亏损限额必须在 0.1%~20% 之间');
      return;
    }

    setState(() => _saving = true);

    final data = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'config': {
        'symbol': widget.strategy.config.symbol,
        'timeframe': widget.strategy.config.timeframe,
        'entry': {
          'type': _entryType,
          'time': _entryTimeController.text.trim(),
          'side': _side,
          'amount_pct': _amountPct,
          'leverage': _leverage,
        },
        'exit': {
          'take_profit_pct': _takeProfitPct,
          'stop_loss_pct': _stopLossPct,
          'max_hold_days': _maxHoldDays,
          'trailing_stop': _trailingStop,
        },
        'risk': {
          'max_position_pct': _maxPositionPct,
          'daily_loss_limit_pct': _dailyLossLimitPct,
          'max_drawdown_pct': _maxDrawdownPct,
        },
        if (!_useFundingRateDefault)
          'funding_rate_override': double.tryParse(_fundingRateController.text.trim()) ?? 0.0001,
      },
    };

    try {
      await apiService.updateStrategy(widget.strategy.id, data);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('保存失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.loss),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('编辑策略'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 基本信息 ──
          _sectionTitle('基本信息'),
          _card([
            _textField('策略名称', _nameController, hint: '给策略起个名字'),
            const SizedBox(height: 12),
            _textField('描述（可选）', _descController, hint: '策略备注...', maxLines: 2),
          ]),

          const SizedBox(height: 20),

          // ── 入场设置 ──
          _sectionTitle('入场设置'),
          _card([
            _label('交易方向'),
            _segRow(['buy', 'sell'], ['买入 (Long) 做多', '卖出 (Short) 做空'], _side, (v) => setState(() => _side = v)),
            const SizedBox(height: 16),
            _label('杠杆倍数  ${_leverage.toInt()}x'),
            Slider(
              value: _leverage, min: 1, max: 125, divisions: 124,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => _leverage = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('1x', style: TextStyle(color: Colors.grey, fontSize: 11)),
              const Text('125x', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            _hint('1x = 无杠杆纯永续；>1x = 合约保证金模式'),
            const SizedBox(height: 16),
            _label('仓位占比  $_amountPct%'),
            Slider(
              value: _amountPct.toDouble(), min: 5, max: 100, divisions: 19,
              activeColor: AppTheme.accent,
              onChanged: (v) => setState(() => _amountPct = v.toInt()),
            ),
            const SizedBox(height: 8),
            _label('执行时间'),
            _textField('执行时间', _entryTimeController, hint: '例如 00:05 UTC'),
          ]),

          const SizedBox(height: 20),

          // ── 出场设置 ──
          _sectionTitle('出场设置'),
          _card([
            _label('止盈  +${_takeProfitPct.toStringAsFixed(1)}%'),
            Slider(
              value: _takeProfitPct, min: 0.5, max: 50, divisions: 99,
              activeColor: AppTheme.accent,
              onChanged: (v) => setState(() => _takeProfitPct = v),
            ),
            const SizedBox(height: 12),
            _label('止损  -${_stopLossPct.toStringAsFixed(1)}%'),
            Slider(
              value: _stopLossPct, min: 0.5, max: 50, divisions: 99,
              activeColor: AppTheme.loss,
              onChanged: (v) => setState(() => _stopLossPct = v),
            ),
            const SizedBox(height: 12),
            _label('最大持仓天数  $_maxHoldDays 天'),
            Slider(
              value: _maxHoldDays.toDouble(), min: 1, max: 30, divisions: 29,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => _maxHoldDays = v.toInt()),
            ),
            const SizedBox(height: 12),
            _switchRow('追踪止损', _trailingStop, (v) => setState(() => _trailingStop = v)),
          ]),

          const SizedBox(height: 20),

          // ── 风控设置 ──
          _sectionTitle('风控设置'),
          _card([
            _label('最大仓位占比  $_maxPositionPct%'),
            Slider(
              value: _maxPositionPct.toDouble(), min: 10, max: 100, divisions: 18,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => _maxPositionPct = v.toInt()),
            ),
            const SizedBox(height: 12),
            _label('日亏损限额  -${_dailyLossLimitPct.toStringAsFixed(1)}%'),
            Slider(
              value: _dailyLossLimitPct, min: 1, max: 20, divisions: 38,
              activeColor: AppTheme.loss,
              onChanged: (v) => setState(() => _dailyLossLimitPct = v),
            ),
            const SizedBox(height: 12),
            _label('最大回撤  -${_maxDrawdownPct.toStringAsFixed(1)}%'),
            Slider(
              value: _maxDrawdownPct, min: 5, max: 50, divisions: 45,
              activeColor: Colors.orange,
              onChanged: (v) => setState(() => _maxDrawdownPct = v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── 资金费率设置 ──
          _sectionTitle('资金费率设置'),
          _card([
            _switchRow('使用默认费率 (0.0001/8h)', _useFundingRateDefault,
                (v) => setState(() => _useFundingRateDefault = v)),
            if (!_useFundingRateDefault) ...[
              const SizedBox(height: 12),
              _textField('自定义费率（每 8 小时）', _fundingRateController,
                  hint: '例如 0.0001', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 4),
              _hint('OKX BTC 永续实际费率在 ±0.0003 间波动，近似 0'),
            ],
            if (_useFundingRateDefault) ...[
              const SizedBox(height: 8),
              _hint('默认费率 0.0001/8h ≈ 年化 13%（偏高估）'),
            ],
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(t, style: const TextStyle(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w600)),
  );

  Widget _card(List<Widget> children) => Card(
    color: AppTheme.surface,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: children, crossAxisAlignment: CrossAxisAlignment.start)),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13)),
  );

  Widget _hint(String t) => Text(t, style: TextStyle(color: Colors.grey[600], fontSize: 11));

  Widget _textField(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard ?? TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _segRow(List<String> values, List<String> labels, String current, ValueChanged<String> onChanged) {
    return Row(
      children: List.generate(values.length, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i < values.length - 1 ? 8 : 0),
          child: _segBtn(labels[i], values[i] == current, () => onChanged(values[i])),
        ),
      )),
    );
  }

  Widget _segBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
        Switch(
          value: value,
          activeColor: AppTheme.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
