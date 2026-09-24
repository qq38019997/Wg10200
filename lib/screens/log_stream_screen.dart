import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto_trader/models/models.dart';
import 'package:crypto_trader/services/api_service.dart';
import 'package:crypto_trader/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// 运行日志：首页全局事件流，WebSocket 订阅后端 /ws/events。
/// 对 SIGNAL_CHECK / ENTRY 事件，展开显示每条策略条件的命中情况（why）。
class LogStreamScreen extends StatefulWidget {
  const LogStreamScreen({super.key});

  @override
  State<LogStreamScreen> createState() => _LogStreamScreenState();
}

class _LogStreamScreenState extends State<LogStreamScreen> {
  final List<StrategyEvent> _events = [];
  WebSocket? _ws;
  Timer? _reconnectTimer;
  bool _connected = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _ws?.close();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final list = await apiService.getEvents(limit: 100);
      if (_disposed) return;
      setState(() {
        _events.clear();
        _events.addAll(list);
      });
    } catch (_) {
      // 历史拉取失败不影响 WebSocket 流
    }
  }

  void _connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    setState(() => _connected = false);
    final token = apiService.rawToken;
    if (token == null) {
      // 未登录，稍后重试
      _scheduleReconnect();
      return;
    }
    final url = '${ApiService.wsBase}?token=$token';
    try {
      final ws = await WebSocket.connect(url);
      _ws = ws;
      setState(() => _connected = true);
      ws.listen(
        (raw) {
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final ev = StrategyEvent.fromJson(data);
            // skip ghost empty events (WS may receive non-event JSON with empty kind/message)
            if (ev.kind.isEmpty && ev.message.isEmpty) return;
            if (_disposed) return;
            setState(() {
              _events.insert(0, ev);
              if (_events.length > 300) {
                _events.removeRange(300, _events.length);
              }
            });
          } catch (_) {
            // 忽略无法解析的消息
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (!_disposed) _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          _StatusDot(connected: _connected),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _ws?.close();
              _connect();
              _loadHistory();
            },
          ),
        ],
      ),
      body: _events.isEmpty
          ? const Center(
              child: Text(
                '暂无运行事件\n策略启动 / 开平仓 / 风控触发后会在此实时显示',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _EventCard(event: _events[i]),
            ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool connected;
  const _StatusDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Icon(
            connected ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: connected ? AppTheme.accent : AppTheme.loss,
          ),
          const SizedBox(width: 4),
          Text(
            connected ? '已连接' : '重连中',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final StrategyEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(event.kind);
    final t = event.createdAt.toLocal();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final conditions = _extractConditions(event.payload);
    final tradeParams = _extractTradeParams(event.payload);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              event.kind,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.message,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                if (tradeParams != null) ...[
                  const SizedBox(height: 6),
                  _TradeParamsView(params: tradeParams),
                ],
                if (conditions != null && conditions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ConditionsView(
                    conditions: conditions,
                    score: (event.payload?['score'] as String?) ?? '',
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    if (event.strategyId != null)
                      Flexible(
                        child: Text(
                          '策略 ${event.strategyId}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>>? _extractConditions(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final raw = payload['conditions'];
    if (raw is! List) return null;
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Map<String, dynamic>? _extractTradeParams(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final Map<String, dynamic> out = {};
    if (payload['stop_loss'] is Map) out['stop_loss'] = payload['stop_loss'];
    if (payload['position_sizing'] is Map) out['position_sizing'] = payload['position_sizing'];
    return out.isEmpty ? null : out;
  }

  Color _kindColor(String kind) {
    final k = kind.toUpperCase();
    if (k == 'TAKE_PROFIT' || k == 'START') return AppTheme.accent;
    if (k == 'STOP_LOSS' || k == 'STOP' || k == 'ERROR') return AppTheme.loss;
    if (k == 'ENTRY') return Colors.blue;
    if (k == 'SIGNAL_CHECK') return Colors.teal;
    if (k == 'FUNDING') return Colors.amber;
    return AppTheme.textSecondary;
  }
}

/// 策略条件命中明细（可折叠）。默认展开——这是用户最关心的「为什么」。
class _ConditionsView extends StatefulWidget {
  final List<Map<String, dynamic>> conditions;
  final String score;
  const _ConditionsView({required this.conditions, required this.score});

  @override
  State<_ConditionsView> createState() => _ConditionsViewState();
}

class _ConditionsViewState extends State<_ConditionsView> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final passed = widget.conditions.where((c) => c['passed'] == true).length;
    final total = widget.conditions.length;
    final allPass = passed == total;
    final headerColor = allPass ? AppTheme.accent : AppTheme.textSecondary;
    final scoreLabel = widget.score.isNotEmpty ? widget.score : '$passed/$total';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  allPass ? Icons.check_circle_outline : Icons.rule,
                  size: 14,
                  color: headerColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '条件 $scoreLabel',
                  style: TextStyle(fontSize: 12, color: headerColor, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            for (final c in widget.conditions) _ConditionRow(cond: c),
          ],
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final Map<String, dynamic> cond;
  const _ConditionRow({required this.cond});

  @override
  Widget build(BuildContext context) {
    final ok = cond['passed'] == true;
    final label = (cond['label'] ?? cond['indicator'] ?? '条件').toString();
    final detail = (cond['detail'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check : Icons.close,
            size: 13,
            color: ok ? AppTheme.accent : AppTheme.loss,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 12,
                      color: ok ? Colors.white : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    TextSpan(
                      text: '  $detail',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 开仓参数：结构位止损 + 动态仓位（选项2 新增字段）。
class _TradeParamsView extends StatelessWidget {
  final Map<String, dynamic> params;
  const _TradeParamsView({required this.params});

  @override
  Widget build(BuildContext context) {
    final sl = params['stop_loss'] as Map<String, dynamic>?;
    final sizing = params['position_sizing'] as Map<String, dynamic>?;
    final chips = <Widget>[];
    if (sl != null) {
      final type = sl['type']?.toString() ?? 'percent';
      if (type == 'structural') {
        final ref = sl['ref']?.toString() ?? '';
        final refPrice = _fmt(sl['ref_price']);
        final offset = _fmt(sl['offset_pct']);
        final stop = _fmt(sl['stop_price']);
        final slPct = _fmt(sl['sl_pct']);
        chips.add(_ParamChip(
          label: '结构位止损',
          value: '$stop（${ref}@$refPrice +$offset%）≈ $slPct%',
        ));
      } else {
        chips.add(_ParamChip(label: '止损', value: '${_fmt(sl['sl_pct'])}%'));
      }
    }
    if (sizing != null) {
      final mode = sizing['mode']?.toString() ?? '';
      final value = _fmt(sizing['value']);
      final base = _fmt(sizing['base_usdt']);
      if (mode == 'available_margin_pct') {
        chips.add(_ParamChip(label: '动态仓位', value: '$value% 可用保证金 ≈ $base USDT'));
      } else {
        chips.add(_ParamChip(label: '仓位', value: value));
      }
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  String _fmt(dynamic v) {
    if (v == null) return '-';
    if (v is num) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(v.abs() < 10 ? 2 : 0);
    }
    return v.toString();
  }
}

class _ParamChip extends StatelessWidget {
  final String label;
  final String value;
  const _ParamChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value, style: const TextStyle(fontSize: 11, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
