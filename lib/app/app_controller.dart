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
  AppConfig _config = AppConfig.fallback();
  DashboardStats _dashboard = DashboardStats.empty();
  List<Product> _products = const [];
  List<OrderModel> _orders = const [];
  List<CartEntry> _cart = const [];

  bool get isBooting => _isBooting;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  AppUser? get currentUser => _currentUser;
  AppConfig get config => _config;
  DashboardStats get dashboard => _dashboard;
  List<Product> get products => List.unmodifiable(_products);
  List<OrderModel> get orders => List.unmodifiable(_orders);
  List<CartEntry> get cart => List.unmodifiable(_cart);
  String get apiBaseUrl => _apiClient.baseUrl;
  UserRole? get currentRole => _currentUser?.role;

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
    if (_currentUser != null) {
      await refreshOrders();
    }
  }

  Future<void> refreshPublicData({bool silent = false}) async {
    await _runBusy(() async {
      _config = await _apiClient.getConfig();
      _products = await _apiClient.getProducts();
    }, silent: silent);
  }

  Future<void> signIn({required String login, required String password}) async {
    await _runBusy(() async {
      final session = await _apiClient.signIn(login: login, password: password);
      _currentUser = session.user;
      _dashboard = DashboardStats.empty();
      await refreshPublicData(silent: true);
      await refreshOrders(silent: true);
      if (_currentUser?.role == UserRole.admin) {
        _dashboard = await _apiClient.getDashboard();
      }
    });
  }

  Future<void> register({
    required String login,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    await _runBusy(() async {
      final session = await _apiClient.register(
        login: login,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _currentUser = session.user;
      _dashboard = DashboardStats.empty();
      await refreshPublicData(silent: true);
      _orders = const [];
      _cart = const [];
    });
  }

  Future<void> logout() async {
    _apiClient.clearSession();
    _currentUser = null;
    _orders = const [];
    _dashboard = DashboardStats.empty();
    _cart = const [];
    _errorMessage = null;
    notifyListeners();
    await refreshPublicData(silent: true);
  }

  Future<void> refreshOrders({bool silent = false}) async {
    if (_currentUser == null) return;
    await _runBusy(() async {
      _orders = await _apiClient.getOrders();
      if (_currentUser?.role == UserRole.admin) {
        _dashboard = await _apiClient.getDashboard();
      }
    }, silent: silent);
  }

  void addToCart(Product product) {
    final index = _cart.indexWhere((entry) => entry.product.id == product.id);
    if (index == -1) {
      _cart = [..._cart, CartEntry(product: product)];
    } else {
      _cart = [
        for (var i = 0; i < _cart.length; i++)
          if (i == index)
            _cart[i].copyWith(quantity: _cart[i].quantity + 1)
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
      order = await _apiClient.createOrder(
        entries: _cart,
        deliveryType: deliveryType,
        location: location,
        paymentMethod: paymentMethod,
        paymentMask: paymentMask,
      );
      _cart = const [];
      _products = await _apiClient.getProducts();
      _orders = await _apiClient.getOrders();
      if (_currentUser?.role == UserRole.admin) {
        _dashboard = await _apiClient.getDashboard();
      }
    });
    return order;
  }

  Future<void> issueOrder({
    required String orderId,
    required String cylinderSerial,
  }) async {
    await _runBusy(() async {
      await _apiClient.issueOrder(
        orderId: orderId,
        cylinderSerial: cylinderSerial,
      );
      await refreshOrders(silent: true);
      _products = await _apiClient.getProducts();
    });
  }

  Future<void> completeOrder(String orderId) async {
    await _runBusy(() async {
      await _apiClient.completeOrder(orderId);
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
      _errorMessage = 'Что-то пошло не так: $error';
      rethrow;
    } finally {
      if (!silent) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }
}
