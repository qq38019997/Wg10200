/// 数据模型
class Strategy {
  final String id;
  final String name;
  final String? description;
  final StrategyConfig config;
  final StrategyStatus status;
  final double totalPnl;
  final int totalTrades;
  final double winRate;
  final DateTime? lastRunAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Strategy({
    required this.id,
    required this.name,
    this.description,
    required this.config,
    required this.status,
    this.totalPnl = 0,
    this.totalTrades = 0,
    this.winRate = 0,
    this.lastRunAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Strategy.fromJson(Map<String, dynamic> json) {
    return Strategy(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      config: StrategyConfig.fromJson(json['config'] ?? {}),
      status: StrategyStatus.fromJson(json['status']),
      totalPnl: (json['total_pnl'] ?? 0).toDouble(),
      totalTrades: json['total_trades'] ?? 0,
      winRate: (json['win_rate'] ?? 0).toDouble(),
      lastRunAt: json['last_run_at'] != null
          ? DateTime.parse(json['last_run_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'config': config.toJson(),
    'status': status.value,
    'total_pnl': totalPnl,
    'total_trades': totalTrades,
    'win_rate': winRate,
  };
}

class StrategyConfig {
  final String symbol;
  final String timeframe;
  final EntryConfig entry;
  final ExitConfig exit;
  final RiskConfig risk;

  StrategyConfig({
    this.symbol = 'BTC/USDT',
    this.timeframe = '1d',
    required this.entry,
    required this.exit,
    required this.risk,
  });

  factory StrategyConfig.fromJson(Map<String, dynamic> json) {
    return StrategyConfig(
      symbol: json['symbol'] ?? 'BTC/USDT',
      timeframe: json['timeframe'] ?? '1d',
      entry: EntryConfig.fromJson(json['entry'] ?? {}),
      exit: ExitConfig.fromJson(json['exit'] ?? {}),
      risk: RiskConfig.fromJson(json['risk'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'timeframe': timeframe,
    'entry': entry.toJson(),
    'exit': exit.toJson(),
    'risk': risk.toJson(),
  };
}

class EntryConfig {
  final String type;
  final String? time;
  final String side;
  final int amountPct;

  EntryConfig({
    this.type = 'scheduled',
    this.time,
    this.side = 'buy',
    this.amountPct = 30,
  });

  factory EntryConfig.fromJson(Map<String, dynamic> json) {
    return EntryConfig(
      type: json['type'] ?? 'scheduled',
      time: json['time'],
      side: json['side'] ?? 'buy',
      amountPct: json['amount_pct'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'time': time,
    'side': side,
    'amount_pct': amountPct,
  };
}

class ExitConfig {
  final double takeProfitPct;
  final double stopLossPct;
  final int maxHoldDays;
  final bool trailingStop;

  ExitConfig({
    this.takeProfitPct = 5.0,
    this.stopLossPct = 3.0,
    this.maxHoldDays = 7,
    this.trailingStop = false,
  });

  factory ExitConfig.fromJson(Map<String, dynamic> json) {
    return ExitConfig(
      takeProfitPct: (json['take_profit_pct'] ?? 5.0).toDouble(),
      stopLossPct: (json['stop_loss_pct'] ?? 3.0).toDouble(),
      maxHoldDays: json['max_hold_days'] ?? 7,
      trailingStop: json['trailing_stop'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'take_profit_pct': takeProfitPct,
    'stop_loss_pct': stopLossPct,
    'max_hold_days': maxHoldDays,
    'trailing_stop': trailingStop,
  };
}

class RiskConfig {
  final int maxPositionPct;
  final double dailyLossLimitPct;
  final double maxDrawdownPct;

  RiskConfig({
    this.maxPositionPct = 80,
    this.dailyLossLimitPct = 5.0,
    this.maxDrawdownPct = 20.0,
  });

  factory RiskConfig.fromJson(Map<String, dynamic> json) {
    return RiskConfig(
      maxPositionPct: json['max_position_pct'] ?? 80,
      dailyLossLimitPct: (json['daily_loss_limit_pct'] ?? 5.0).toDouble(),
      maxDrawdownPct: (json['max_drawdown_pct'] ?? 20.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'max_position_pct': maxPositionPct,
    'daily_loss_limit_pct': dailyLossLimitPct,
    'max_drawdown_pct': maxDrawdownPct,
  };
}

enum StrategyStatus {
  draft, saved, running, paused, stopped, error;

  static StrategyStatus fromJson(String v) {
    return StrategyStatus.values.firstWhere(
      (e) => e.value == v,
      orElse: () => StrategyStatus.saved,
    );
  }

  String get value => name;

  String get label {
    switch (this) {
      case StrategyStatus.running: return '运行中';
      case StrategyStatus.paused: return '已暂停';
      case StrategyStatus.stopped: return '已停止';
      case StrategyStatus.error: return '异常';
      case StrategyStatus.saved: return '已保存';
      case StrategyStatus.draft: return '草稿';
    }
  }
}
