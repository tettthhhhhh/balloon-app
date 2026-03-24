import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8787/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8787/api';
      default:
        return 'http://127.0.0.1:8787/api';
    }
  }

  String baseUrl;
  String? _token;

  void clearSession() {
    _token = null;
  }

  Future<AuthSession> signIn({
    required String login,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/auth/login',
      body: {'login': login, 'password': password},
    );

    final session = AuthSession(
      token: data['token'] as String? ?? '',
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    _token = session.token;
    return session;
  }

  Future<AuthSession> register({
    required String login,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final data = await _request(
      'POST',
      '/auth/register',
      body: {
        'login': login,
        'password': password,
        'fullName': fullName,
        'phone': phone,
      },
    );

    final session = AuthSession(
      token: data['token'] as String? ?? '',
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
    _token = session.token;
    return session;
  }

  Future<AppConfig> getConfig() async {
    final data = await _request('GET', '/config');
    return AppConfig.fromJson(data['config'] as Map<String, dynamic>);
  }

  Future<AppConfig> updateConfig(AppConfig config) async {
    final data = await _request('PATCH', '/config', body: config.toJson());
    return AppConfig.fromJson(data['config'] as Map<String, dynamic>);
  }

  Future<List<Product>> getProducts() async {
    final data = await _request('GET', '/products');
    final items = (data['products'] as List<dynamic>? ?? const []);
    return items
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Product> updateProduct(Product product) async {
    final data = await _request(
      'PATCH',
      '/products/${product.id}',
      body: product.toJson(),
    );
    return Product.fromJson(data['product'] as Map<String, dynamic>);
  }

  Future<List<OrderModel>> getOrders() async {
    final data = await _request('GET', '/orders');
    final items = (data['orders'] as List<dynamic>? ?? const []);
    return items
        .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<OrderModel> createOrder({
    required List<CartEntry> entries,
    required String deliveryType,
    required String location,
    required String paymentMethod,
    required String paymentMask,
  }) async {
    final data = await _request(
      'POST',
      '/orders',
      body: {
        'deliveryType': deliveryType,
        'location': location,
        'paymentMethod': paymentMethod,
        'paymentMask': paymentMask,
        'items': [
          for (final entry in entries)
            {'productId': entry.product.id, 'quantity': entry.quantity},
        ],
      },
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<OrderModel> issueOrder({
    required String orderId,
    required String cylinderSerial,
  }) async {
    final data = await _request(
      'POST',
      '/orders/$orderId/issue',
      body: {'cylinderSerial': cylinderSerial},
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<OrderModel> completeOrder(String orderId) async {
    final data = await _request('POST', '/orders/$orderId/complete');
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<DashboardStats> getDashboard() async {
    final data = await _request('GET', '/dashboard');
    return DashboardStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    late final http.Response response;
    final encoded = body == null ? null : jsonEncode(body);

    try {
      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encoded);
          break;
        default:
          response = await http.get(uri, headers: headers);
      }
    } catch (_) {
      throw ApiException(
        'Не удалось подключиться к API. Проверь адрес сервера: $baseUrl',
      );
    }

    final dynamic payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 400) {
      final message = payload is Map<String, dynamic>
          ? payload['message'] as String? ??
                'Сервер вернул ошибку ${response.statusCode}'
          : 'Сервер вернул ошибку ${response.statusCode}';
      throw ApiException(message);
    }

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('Сервер вернул неожиданный ответ.');
    }

    return payload;
  }

  Uri _buildUri(String path) {
    final target = '$baseUrl$path';
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return Uri.parse(target);
    }

    return Uri.base.resolve(target);
  }
}
