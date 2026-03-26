import 'package:flutter/foundation.dart';

import 'models/app_models.dart';
import 'services/api_client.dart';

class AppController extends ChangeNotifier {
  AppController({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  bool _isBooting = true;
  bool _isBusy = false;
  String? _errorMessage;
  AppUser? _currentUser;
  VerificationState? _verification;
  AppConfig _config = AppConfig.fallback();
  DashboardStats _dashboard = DashboardStats.empty();
  AdminRiskOverview _riskOverview = AdminRiskOverview.empty();
  List<Product> _products = const [];
  List<OrderModel> _orders = const [];
  List<CartEntry> _cart = const [];

  bool get isBooting => _isBooting;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  AppUser? get currentUser => _currentUser;
  VerificationState? get verification => _verification;
  bool get needsVerification => _verification?.required ?? false;
  AppConfig get config => _config;
  DashboardStats get dashboard => _dashboard;
  AdminRiskOverview get riskOverview => _riskOverview;
  List<Product> get products => List.unmodifiable(_products);
  List<OrderModel> get orders => List.unmodifiable(_orders);
  List<CartEntry> get cart => List.unmodifiable(_cart);
  String get apiBaseUrl => _apiClient.baseUrl;
  UserRole? get currentRole => _currentUser?.role;
  bool get canCreateOrders => _currentUser?.canCreateOrders ?? true;

  int get cartItemsCount => _cart.fold(0, (sum, entry) => sum + entry.quantity);
  int get cartTotal => _cart.fold(0, (sum, entry) => sum + entry.subtotal);

  List<OrderModel> get paidOrders => _orders
      .where((order) => order.status == OrderStatus.paid)
      .toList(growable: false);

  List<OrderModel> get activeOrders => _orders
      .where((order) => order.status == OrderStatus.active)
      .toList(growable: false);

  List<OrderModel> get completedOrders => _orders
      .where((order) => order.status == OrderStatus.completed)
      .toList(growable: false);

  List<Product> get featuredProducts =>
      _products.where((product) => product.featured).toList(growable: false);

  Future<void> bootstrap() async {
    try {
      await refreshPublicData(silent: true);
    } catch (_) {
      // Keep fallback public data and let the auth screen surface the error.
    } finally {
      _isBooting = false;
      notifyListeners();
    }
  }

  Future<void> setApiBaseUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == _apiClient.baseUrl) {
      return;
    }
    _apiClient.baseUrl = trimmed;
    notifyListeners();
    await refreshPublicData();
    if (_currentUser != null && !needsVerification) {
      await refreshOrders();
    }
  }

  Future<void> refreshPublicData({bool silent = false}) async {
    await _runBusy(() async {
      _config = await _apiClient.getConfig();
      _products = await _apiClient.getProducts();
    }, silent: silent);
  }

  void _applySession(AuthSession session) {
    _currentUser = session.user;
    _verification = session.verification.required ? session.verification : null;
  }

  Future<void> _refreshSessionState() async {
    if (_currentUser == null) {
      return;
    }
    final session = await _apiClient.getCurrentSession();
    _applySession(session);
  }

  Future<void> _refreshPrivateStateForCurrentUser() async {
    if (_currentUser == null) {
      _orders = const [];
      _cart = const [];
      _dashboard = DashboardStats.empty();
      _riskOverview = AdminRiskOverview.empty();
      return;
    }

    await _refreshSessionState();

    if (needsVerification) {
      _orders = const [];
      _cart = const [];
      _dashboard = DashboardStats.empty();
      _riskOverview = AdminRiskOverview.empty();
      return;
    }

    _orders = await _apiClient.getOrders();
    if (_currentUser?.role == UserRole.admin) {
      _dashboard = await _apiClient.getDashboard();
      _riskOverview = await _apiClient.getRiskOverview();
    } else {
      _dashboard = DashboardStats.empty();
      _riskOverview = AdminRiskOverview.empty();
    }
  }

  Future<void> signIn({required String login, required String password}) async {
    await _runBusy(() async {
      final session = await _apiClient.signIn(login: login, password: password);
      _applySession(session);
      await refreshPublicData(silent: true);
      await _refreshPrivateStateForCurrentUser();
    });
  }

  Future<void> register({
    required String login,
    required String password,
    required String fullName,
    required String phone,
    required String email,
  }) async {
    await _runBusy(() async {
      final session = await _apiClient.register(
        login: login,
        password: password,
        fullName: fullName,
        phone: phone,
        email: email,
      );
      _applySession(session);
      await refreshPublicData(silent: true);
      await _refreshPrivateStateForCurrentUser();
    });
  }

  Future<void> resendVerification({VerificationChannel? channel}) async {
    await _runBusy(() async {
      final session = await _apiClient.resendVerification(
        channel: channel?.wireName,
      );
      _applySession(session);
    });
  }

  Future<void> confirmVerification({
    required String verificationId,
    required String code,
  }) async {
    await _runBusy(() async {
      final session = await _apiClient.confirmVerification(
        verificationId: verificationId,
        code: code,
      );
      _applySession(session);
      await _refreshPrivateStateForCurrentUser();
    });
  }

  Future<void> logout() async {
    _apiClient.clearSession();
    _currentUser = null;
    _verification = null;
    _orders = const [];
    _dashboard = DashboardStats.empty();
    _riskOverview = AdminRiskOverview.empty();
    _cart = const [];
    _errorMessage = null;
    notifyListeners();
    try {
      await refreshPublicData(silent: true);
    } catch (_) {
      // Logout should still succeed even if public API is temporarily down.
    }
    notifyListeners();
  }

  Future<void> refreshOrders({bool silent = false}) async {
    if (_currentUser == null || needsVerification) return;
    await _runBusy(() async {
      await _refreshSessionState();
      if (needsVerification) {
        _orders = const [];
        _dashboard = DashboardStats.empty();
        _riskOverview = AdminRiskOverview.empty();
        return;
      }
      _orders = await _apiClient.getOrders();
      if (_currentUser?.role == UserRole.admin) {
        _dashboard = await _apiClient.getDashboard();
        _riskOverview = await _apiClient.getRiskOverview();
      } else {
        _dashboard = DashboardStats.empty();
        _riskOverview = AdminRiskOverview.empty();
      }
    }, silent: silent);
  }

  void addToCart(Product product, {int quantity = 1}) {
    if (quantity <= 0) {
      return;
    }
    final index = _cart.indexWhere((entry) => entry.product.id == product.id);
    if (index == -1) {
      _cart = [..._cart, CartEntry(product: product, quantity: quantity)];
    } else {
      _cart = [
        for (var i = 0; i < _cart.length; i++)
          if (i == index)
            _cart[i].copyWith(quantity: _cart[i].quantity + quantity)
          else
            _cart[i],
      ];
    }
    notifyListeners();
  }

  void updateCartQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    _cart = [
      for (final entry in _cart)
        if (entry.product.id == productId)
          entry.copyWith(quantity: quantity)
        else
          entry,
    ];
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart = _cart.where((entry) => entry.product.id != productId).toList();
    notifyListeners();
  }

  void clearCart() {
    _cart = const [];
    notifyListeners();
  }

  Future<OrderModel> submitOrder({
    required String deliveryType,
    required String location,
    required String paymentMethod,
    required String paymentMask,
  }) async {
    late final OrderModel order;
    await _runBusy(() async {
      final deviceInfo = kIsWeb
          ? 'flutter-web-checkout'
          : 'flutter-mobile-checkout';
      order = await _apiClient.submitCheckout(
        entries: _cart,
        deliveryType: deliveryType,
        location: location,
        paymentMethod: paymentMethod,
        paymentMask: paymentMask,
        deviceInfo: deviceInfo,
      );
      _cart = const [];
      _products = await _apiClient.getProducts();
      _orders = await _apiClient.getOrders();
      if (_currentUser?.role == UserRole.admin) {
        _dashboard = await _apiClient.getDashboard();
        _riskOverview = await _apiClient.getRiskOverview();
      }
    });
    return order;
  }

  Future<void> issueOrder({
    required String orderId,
    required List<String> cylinderSerials,
  }) async {
    await _runBusy(() async {
      await _apiClient.issueOrder(
        orderId: orderId,
        cylinderSerials: cylinderSerials,
      );
      await refreshOrders(silent: true);
      _products = await _apiClient.getProducts();
    });
  }

  Future<void> completeOrder({
    required String orderId,
    List<String> returnedCodes = const [],
  }) async {
    await _runBusy(() async {
      await _apiClient.completeOrder(
        orderId: orderId,
        returnedCodes: returnedCodes,
      );
      await refreshOrders(silent: true);
      _products = await _apiClient.getProducts();
    });
  }

  Future<void> updateProduct(Product product) async {
    await _runBusy(() async {
      final updated = await _apiClient.updateProduct(product);
      _products = [
        for (final current in _products)
          if (current.id == updated.id) updated else current,
      ];
      if (_currentUser?.role == UserRole.admin) {
        _dashboard = await _apiClient.getDashboard();
      }
    });
  }

  Future<void> updateConfig(AppConfig config) async {
    await _runBusy(() async {
      _config = await _apiClient.updateConfig(config);
    });
  }

  Future<void> blockUserOrders({
    required String userId,
    required String reason,
    int? blockedDays,
  }) async {
    await _runBusy(() async {
      await _apiClient.blockUserOrders(
        userId: userId,
        reason: reason,
        blockedDays: blockedDays,
      );
      await refreshOrders(silent: true);
    });
  }

  Future<void> unblockUserOrders({
    required String userId,
    String? reason,
  }) async {
    await _runBusy(() async {
      await _apiClient.unblockUserOrders(userId: userId, reason: reason);
      await refreshOrders(silent: true);
    });
  }

  Future<void> forceCompleteOrder({
    required String orderId,
    String? reason,
  }) async {
    await _runBusy(() async {
      await _apiClient.forceCompleteOrder(orderId: orderId, reason: reason);
      await refreshOrders(silent: true);
      _products = await _apiClient.getProducts();
    });
  }

  Future<ContractModel> getOrderContract(String orderId) {
    return _apiClient.getOrderContract(orderId);
  }

  Future<ContractAccessModel> issueContractAccessLink(String contractId) {
    return _apiClient.issueContractAccessLink(contractId);
  }

  Uri resolveExternalUrl(String path) => _apiClient.resolveExternalUrl(path);

  Future<PaymentModel> getOrderPayment(String orderId) {
    return _apiClient.getOrderPayment(orderId);
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    bool silent = false,
  }) async {
    if (!silent) {
      _isBusy = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await action();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (error) {
      _errorMessage =
          'Что-то пошло не так. Попробуйте ещё раз или обновите экран.';
      rethrow;
    } finally {
      if (!silent) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }
}
