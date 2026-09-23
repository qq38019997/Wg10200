import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://47.82.76.6:8000/api/v1';

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (err, handler) {
        if (err.response?.statusCode == 401) {
          // Token 过期，清除并跳转登录
          _storage.delete(key: 'access_token');
        }
        handler.next(err);
      },
    ));
  }

  /// 统一的网络重试：处理超时/连接错误/5xx。最多重试 2 次，间隔 1.5s/3s。
  Future<T> _withRetry<T>(Future<T> Function() fn, {String op = ''}) async {
    const delays = [Duration(seconds: 0), Duration(seconds: 2), Duration(seconds: 4)];
    Object? lastErr;
    for (var i = 0; i < delays.length; i++) {
      if (delays[i].inSeconds > 0) {
        await Future.delayed(delays[i]);
      }
      try {
        return await fn();
      } catch (e) {
        lastErr = e;
        final transient = e is DioException &&
            (e.type == DioExceptionType.receiveTimeout ||
             e.type == DioExceptionType.sendTimeout ||
             e.type == DioExceptionType.connectionTimeout ||
             e.type == DioExceptionType.connectionError ||
             (e.response?.statusCode != null && e.response!.statusCode! >= 500));
        if (!transient || i == delays.length - 1) rethrow;
        if (kDebugMode) debugPrint('[$op] retry ${i + 1}/2: $e');
      }
    }
    throw lastErr!;
  }

  // ── 认证 ────────────────────────────────────────────────
  Future<String> register(String username, String password) async {
    final resp = await _withRetry(
      () => _dio.post('/auth/register', data: {
        'username': username, 'password': password,
      }),
      op: 'register',
    );
    final token = resp.data['access_token'];
    await _storage.write(key: 'access_token', value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
    return token;
  }

  Future<String> login(String username, String password) async {
    final resp = await _withRetry(
      () => _dio.post('/auth/login', data: {
        'username': username, 'password': password,
      }),
      op: 'login',
    );
    final token = resp.data['access_token'];
    await _storage.write(key: 'access_token', value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
    return token;
  }

  Future<void> restoreToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    _dio.options.headers.remove('Authorization');
  }

  // ── 策略 ─────────────────────────────────────────────────
  Future<List<Strategy>> getStrategies({StrategyStatus? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status.value;
    final resp = await _withRetry(
      () => _dio.get('/strategies', queryParameters: params),
      op: 'getStrategies',
    );
    return (resp.data as List).map((e) => Strategy.fromJson(e)).toList();
  }

  Future<Strategy> createStrategy({
    required String name,
    String? description,
    required Map<String, dynamic> config,
  }) async {
    final resp = await _withRetry(
      () => _dio.post('/strategies', data: {
        'name': name, 'description': description, 'config': config,
      }),
      op: 'createStrategy',
    );
    return Strategy.fromJson(resp.data);
  }

  Future<Strategy> updateStrategy(String id, Map<String, dynamic> data) async {
    final resp = await _withRetry(
      () => _dio.put('/strategies/$id', data: data),
      op: 'updateStrategy',
    );
    return Strategy.fromJson(resp.data);
  }

  Future<void> deleteStrategy(String id) async {
    await _withRetry(() => _dio.delete('/strategies/$id'), op: 'deleteStrategy');
  }

  // ── AI 生成策略 ─────────────────────────────────────────
  Future<Map<String, dynamic>> generateStrategy(String prompt) async {
    final resp = await _withRetry(
      () => _dio.post('/ai/generate', data: {'prompt': prompt}),
      op: 'generateStrategy',
    );
    return resp.data;  // {dsl, explanation, raw_response}
  }

  Future<String> aiChat(String message, {String? strategyId}) async {
    final resp = await _withRetry(
      () => _dio.post('/ai/chat', data: {
        'message': message, 'strategy_id': strategyId,
      }),
      op: 'aiChat',
    );
    return resp.data['reply'];
  }

  // ── 回测 ────────────────────────────────────────────────
  Future<Map<String, dynamic>> runBacktest({
    required String strategyId,
    required DateTime startDate,
    required DateTime endDate,
    double initialBalance = 10000,
  }) async {
    final resp = await _withRetry(
      () => _dio.post('/backtest', data: {
        'strategy_id': strategyId,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'initial_balance': initialBalance,
      }),
      op: 'runBacktest',
    );
    return resp.data;
  }

  // ── 实盘 ────────────────────────────────────────────────
  Future<void> startStrategy(String strategyId) async {
    await _withRetry(
      () => _dio.post('/live/start', data: {'strategy_id': strategyId}),
      op: 'startStrategy',
    );
  }

  Future<void> stopStrategy(String strategyId) async {
    await _withRetry(
      () => _dio.post('/live/stop', data: {'strategy_id': strategyId}),
      op: 'stopStrategy',
    );
  }

  Future<void> switchMode(String mode) async {
    await _withRetry(
      () => _dio.post('/live/switch-mode', data: {'mode': mode}),
      op: 'switchMode',
    );
  }

  // ── 行情 ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTicker(String symbol) async {
    final resp = await _withRetry(
      () => _dio.get('/market/ticker/$symbol'),
      op: 'getTicker',
    );
    return resp.data;
  }

  Future<List<Map<String, dynamic>>> getKline(
    String symbol, {
    String timeframe = '1d',
    int limit = 100,
  }) async {
    final resp = await _withRetry(
      () => _dio.get('/market/kline/$symbol', queryParameters: {
        'timeframe': timeframe, 'limit': limit,
      }),
      op: 'getKline',
    );
    return List<Map<String, dynamic>>.from(resp.data);
  }

  Future<Map<String, dynamic>> getTickers(String symbols) async {
    final resp = await _withRetry(
      () => _dio.get('/market/tickers', queryParameters: {
        'symbols': symbols,
      }),
      op: 'getTickers',
    );
    return Map<String, dynamic>.from(resp.data);
  }

  // ── OKX Key 配置 ─────────────────────────────────────────
  Future<void> setOKXKey(String apiKey, String secret, String passphrase) async {
    await _withRetry(
      () => _dio.post('/auth/okx-key', data: {
        'api_key': apiKey,
        'secret': secret,
        'passphrase': passphrase,
      }),
      op: 'setOKXKey',
    );
  }

  Future<Map<String, dynamic>> getOKXKeyStatus() async {
    final resp = await _withRetry(() => _dio.get('/auth/okx-key'), op: 'getOKXKeyStatus');
    return resp.data;
  }
}

// ── 全局单例 ────────────────────────────────────────────────
final apiService = ApiService();
