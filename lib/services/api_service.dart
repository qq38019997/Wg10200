/// API 服务（dio HTTP 客户端）
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://47.82.76.6/api/v1';

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  /// 检查是否已有 token
  bool get hasToken => _dio.options.headers['Authorization'] != null;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
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

  // ── 认证 ────────────────────────────────────────────────
  Future<String> register(String username, String password) async {
    final resp = await _dio.post('/auth/register', data: {
      'username': username, 'password': password,
    });
    final token = resp.data['access_token'];
    await _storage.write(key: 'access_token', value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
    return token;
  }

  Future<String> login(String username, String password) async {
    final resp = await _dio.post('/auth/login', data: {
      'username': username, 'password': password,
    });
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
    final resp = await _dio.get('/strategies', queryParameters: params);
    return (resp.data as List).map((e) => Strategy.fromJson(e)).toList();
  }

  Future<Strategy> createStrategy({
    required String name,
    String? description,
    required Map<String, dynamic> config,
  }) async {
    final resp = await _dio.post('/strategies', data: {
      'name': name, 'description': description, 'config': config,
    });
    return Strategy.fromJson(resp.data);
  }

  Future<Strategy> updateStrategy(String id, Map<String, dynamic> data) async {
    final resp = await _dio.put('/strategies/$id', data: data);
    return Strategy.fromJson(resp.data);
  }

  Future<void> deleteStrategy(String id) async {
    await _dio.delete('/strategies/$id');
  }

  // ── AI 生成策略 ─────────────────────────────────────────
  Future<Map<String, dynamic>> generateStrategy(String prompt) async {
    final resp = await _dio.post('/ai/generate', data: {'prompt': prompt});
    return resp.data;  // {dsl, explanation, raw_response}
  }

  Future<String> aiChat(String message, {String? strategyId}) async {
    final resp = await _dio.post('/ai/chat', data: {
      'message': message, 'strategy_id': strategyId,
    });
    return resp.data['reply'];
  }

  // ── 回测 ────────────────────────────────────────────────
  Future<Map<String, dynamic>> runBacktest({
    required String strategyId,
    required DateTime startDate,
    required DateTime endDate,
    double initialBalance = 10000,
  }) async {
    final resp = await _dio.post('/backtest', data: {
      'strategy_id': strategyId,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'initial_balance': initialBalance,
    });
    return resp.data;
  }

  // ── 实盘 ────────────────────────────────────────────────
  Future<void> startStrategy(String strategyId) async {
    await _dio.post('/live/start', data: {'strategy_id': strategyId});
  }

  Future<void> stopStrategy(String strategyId) async {
    await _dio.post('/live/stop', data: {'strategy_id': strategyId});
  }

  Future<void> switchMode(String mode) async {
    await _dio.post('/live/switch-mode', data: {'mode': mode});
  }

  // ── 行情 ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTicker(String symbol) async {
    final resp = await _dio.get('/market/ticker/$symbol');
    return resp.data;
  }

  Future<List<Map<String, dynamic>>> getKline(
    String symbol, {
    String timeframe = '1d',
    int limit = 100,
  }) async {
    final resp = await _dio.get('/market/kline/$symbol', queryParameters: {
      'timeframe': timeframe, 'limit': limit,
    });
    return List<Map<String, dynamic>>.from(resp.data);
  }

  Future<Map<String, dynamic>> getTickers(String symbols) async {
    final resp = await _dio.get('/market/tickers', queryParameters: {
      'symbols': symbols,
    });
    return Map<String, dynamic>.from(resp.data);
  }

  // ── 用户信息 ──────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final resp = await _dio.get('/auth/me');
    return resp.data; // {id, username, is_admin, activated_until}
  }

  // ── 激活码 ──────────────────────────────────────────────
  Future<Map<String, dynamic>> activate(String code) async {
    final resp = await _dio.post('/activation/activate', data: {'code': code});
    return resp.data; // {activated, activated_until, type}
  }

  Future<Map<String, dynamic>> getActivationStatus() async {
    final resp = await _dio.get('/activation/status');
    return resp.data; // {activated, activated_until, type}
  }

  Future<List<dynamic>> listActivationCodes() async {
    final resp = await _dio.get('/activation/codes');
    return resp.data; // [{code, type, status, ...}]
  }

  Future<Map<String, dynamic>> generateCodes(String type, int count) async {
    final resp = await _dio.post('/activation/generate', data: {
      'type': type, 'count': count,
    });
    return resp.data; // {codes: [...], count}
  }

  // ── OKX Key 配置 ─────────────────────────────────────────
  Future<void> setOKXKey(String apiKey, String secret, String passphrase) async {
    await _dio.post('/auth/okx-key', data: {
      'api_key': apiKey,
      'secret': secret,
      'passphrase': passphrase,
    });
  }

  Future<Map<String, dynamic>> getOKXKeyStatus() async {
    final resp = await _dio.get('/auth/okx-key');
    return resp.data;
  }
}

// ── 全局单例 ────────────────────────────────────────────────
final apiService = ApiService();
