import 'dart:async';
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
  const AuthSession({
    required this.token,
    required this.user,
    required this.verification,
  });

  final String token;
  final AppUser user;
  final VerificationState verification;
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 15);

  static String get defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isLocalHost =
          host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
      if (!isLocalHost) {
        return '/api';
      }
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

  AuthSession _parseAuthSession(
    Map<String, dynamic> data, {
    String? fallbackToken,
  }) {
    final token = data['token'] as String? ?? fallbackToken ?? '';
    final session = AuthSession(
      token: token,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      verification: VerificationState.fromJson(
        (data['verification'] as Map<String, dynamic>?) ?? const {},
      ),
    );
    _token = session.token.isEmpty ? _token : session.token;
    return session;
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
    return _parseAuthSession(data);
  }

  Future<AuthSession> register({
    required String login,
    required String password,
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final data = await _request(
      'POST',
      '/auth/register',
      body: {
        'login': login,
        'password': password,
        'fullName': fullName,
        'phone': phone,
        'email': email,
      },
    );
    return _parseAuthSession(data);
  }

  Future<AuthSession> getCurrentSession() async {
    final data = await _request('GET', '/auth/me');
    return _parseAuthSession(data, fallbackToken: _token);
  }

  Future<AuthSession> resendVerification({String? channel}) async {
    final data = await _request(
      'POST',
      '/auth/verification/resend',
      body: {if (channel != null && channel.isNotEmpty) 'channel': channel},
    );
    return _parseAuthSession(data, fallbackToken: _token);
  }

  Future<AuthSession> confirmVerification({
    required String verificationId,
    required String code,
  }) async {
    final data = await _request(
      'POST',
      '/auth/verification/confirm',
      body: {'verificationId': verificationId, 'code': code},
    );
    return _parseAuthSession(data, fallbackToken: _token);
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

  Future<OrderModel> signContractStub({
    required String orderId,
    required String deviceInfo,
  }) async {
    final data = await _request(
      'POST',
      '/orders/$orderId/contracts/sign-stub',
      body: {'deviceInfo': deviceInfo},
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<OrderModel> confirmPaymentStub({
    required String orderId,
    required String paymentMethod,
    required String paymentMask,
  }) async {
    final data = await _request(
      'POST',
      '/orders/$orderId/payments/confirm-stub',
      body: {'paymentMethod': paymentMethod, 'paymentMask': paymentMask},
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<OrderModel> submitCheckout({
    required List<CartEntry> entries,
    required String deliveryType,
    required String location,
    required String paymentMethod,
    required String paymentMask,
    required String deviceInfo,
  }) async {
    final created = await createOrder(
      entries: entries,
      deliveryType: deliveryType,
      location: location,
      paymentMethod: paymentMethod,
      paymentMask: paymentMask,
    );
    await signContractStub(orderId: created.id, deviceInfo: deviceInfo);
    return confirmPaymentStub(
      orderId: created.id,
      paymentMethod: paymentMethod,
      paymentMask: paymentMask,
    );
  }

  Future<ContractModel> getOrderContract(String orderId) async {
    final data = await _request('GET', '/orders/$orderId/contract');
    return ContractModel.fromJson(data['contract'] as Map<String, dynamic>);
  }

  Future<ContractAccessModel> issueContractAccessLink(String contractId) async {
    final data = await _request('POST', '/contracts/$contractId/access-link');
    return ContractAccessModel.fromJson(data['access'] as Map<String, dynamic>);
  }

  Future<PaymentModel> getOrderPayment(String orderId) async {
    final data = await _request('GET', '/orders/$orderId/payment');
    return PaymentModel.fromJson(data['payment'] as Map<String, dynamic>);
  }

  Future<OrderModel> issueOrder({
    required String orderId,
    required List<String> cylinderSerials,
  }) async {
    final data = await _request(
      'POST',
      '/orders/$orderId/issue',
      body: {
        'cylinderSerials': cylinderSerials,
        if (cylinderSerials.length == 1)
          'cylinderSerial': cylinderSerials.first,
      },
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<OrderModel> completeOrder({
    required String orderId,
    List<String> returnedCodes = const [],
  }) async {
    final data = await _request(
      'POST',
      '/orders/$orderId/complete',
      body: {
        'returnedCodes': returnedCodes,
        if (returnedCodes.length == 1) 'returnedCode': returnedCodes.first,
      },
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<DashboardStats> getDashboard() async {
    final data = await _request('GET', '/dashboard');
    return DashboardStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<AdminRiskOverview> getRiskOverview() async {
    final data = await _request('GET', '/admin/risk-overview');
    return AdminRiskOverview.fromJson(data);
  }

  Future<AppUser> blockUserOrders({
    required String userId,
    required String reason,
    int? blockedDays,
  }) async {
    final data = await _request(
      'POST',
      '/admin/users/$userId/block-orders',
      body: {
        'reason': reason,
        if (blockedDays != null && blockedDays > 0) 'blockedDays': blockedDays,
      },
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> unblockUserOrders({
    required String userId,
    String? reason,
  }) async {
    final data = await _request(
      'POST',
      '/admin/users/$userId/unblock-orders',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<OrderModel> forceCompleteOrder({
    required String orderId,
    String? reason,
  }) async {
    final data = await _request(
      'POST',
      '/admin/orders/$orderId/force-complete',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return OrderModel.fromJson(data['order'] as Map<String, dynamic>);
  }

  Uri resolveExternalUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return Uri();
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }

    if (baseUrl.startsWith('http://') || baseUrl.startsWith('https://')) {
      return Uri.parse(baseUrl).resolve(trimmed);
    }

    return Uri.base.resolve(trimmed);
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
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(_requestTimeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: encoded)
              .timeout(_requestTimeout);
          break;
        default:
          response = await http
              .get(uri, headers: headers)
              .timeout(_requestTimeout);
      }
    } on TimeoutException {
      throw const ApiException(
        'Сервер отвечает слишком долго. Попробуйте ещё раз.',
      );
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
