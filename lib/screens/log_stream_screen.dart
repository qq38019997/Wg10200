import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// 首页「日志」Tab：拉取历史 + 通过 WebSocket 实时接收全部策略事件流。
class LogStreamScreen extends StatefulWidget {
  const LogStreamScreen({super.key});

  @override
  State<LogStreamScreen> createState() => _LogStreamScreenState();
}

class _LogStreamScreenState extends State<LogStreamScreen> {
  final List<StrategyEvent> _events = [];
  final Set<String> _seen = {};
  bool _loading = true;
  bool _connected = false;
  String? _error;
  WebSocket? _ws;
  bool _disposed = false;
  Timer? _reconnectTimer;

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
      final data = await apiService.getEvents(limit: 200);
      if (_disposed) return;
      setState(() {
        _events.clear();
        _seen.clear();
        for (final e in data.reversed) {
          _events.add(e);
          _seen.add(e.id);
        }
        _loading = false;
      });
    } catch (e) {
      if (_disposed) return;
      setState(() {
        _loading = false;
        if (_events.isEmpty) _error = e.toString();
      });
    }
  }

  void _connect() {
    final token = apiService.rawToken;
    if (token == null) {
      if (!_disposed) setState(() => _error = '未登录');
      return;
    }
    final url = '${ApiService.wsBase}?token=$token';
    WebSocket.connect(url).then((ws) {
      if (_disposed) {
        ws.close();
        return;
      }
      _ws = ws;
      if (!_disposed) setState(() => _connected = true);
      ws.listen(
        (raw) {
          try {
            final d = jsonDecode(raw) as Map<String, dynamic>;
            final ev = StrategyEvent.fromJson(d);
            if (_disposed || _seen.contains(ev.id)) return;
            setState(() {
              _events.insert(0, ev);
              _seen.add(ev.id);
            });
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (!_disposed) setState(() => _connected = false);
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    }).catchError((_) => _scheduleReconnect());
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (!_disposed) setState(() => _connected = false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          _StatusDot(connected: _connected),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _events.isEmpty
              ? _buildError()
              : _events.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _EventCard(event: _events[i]),
                    ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            const Text('暂无日志', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('启动策略后，事件会在这里出现', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 16),
            const Text('加载失败', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('可能是网络到服务器延迟偏高，点下方按钮重试。', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('重试')),
          ],
        ),
      );
}

class _StatusDot extends StatelessWidget {
  final bool connected;
  const _StatusDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Icon(connected ? Icons.circle : Icons.circle_outlined,
              size: 12, color: connected ? AppTheme.accent : Colors.grey),
          const SizedBox(width: 6),
          Text(connected ? '在线' : '离线', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final StrategyEvent event;
  const _EventCard({required this.event});

  Color get _badgeColor {
    final k = event.kind.toUpperCase();
    if (k == 'TAKE_PROFIT' || k == 'EXIT') return AppTheme.accent;
    if (k == 'STOP_LOSS' || k == 'ERROR' || event.level == 'error') return AppTheme.loss;
    if (k == 'FUNDING' || event.level == 'warn') return Colors.amber;
    if (k == 'ENTRY' || k == 'START' || k == 'RESUME') return Colors.blue;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final t = event.createdAt.toLocal();
    final ts = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final sid = event.strategyId != null && event.strategyId!.length >= 8
        ? event.strategyId!.substring(0, 8)
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(event.kind, style: TextStyle(color: _badgeColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.message, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(ts, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (sid != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('策略 $sid', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
