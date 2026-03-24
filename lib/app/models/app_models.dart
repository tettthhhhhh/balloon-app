enum UserRole { client, courier, admin }

extension UserRoleX on UserRole {
  String get wireName => switch (this) {
    UserRole.client => 'client',
    UserRole.courier => 'courier',
    UserRole.admin => 'admin',
  };

  String get title => switch (this) {
    UserRole.client => 'Клиент',
    UserRole.courier => 'Курьер',
    UserRole.admin => 'Админ',
  };

  static UserRole fromWire(String value) => switch (value) {
    'admin' => UserRole.admin,
    'courier' => UserRole.courier,
    _ => UserRole.client,
  };
}

enum OrderStatus { paid, active, completed }

extension OrderStatusX on OrderStatus {
  String get wireName => switch (this) {
    OrderStatus.paid => 'paid',
    OrderStatus.active => 'active',
    OrderStatus.completed => 'completed',
  };

  String get title => switch (this) {
    OrderStatus.paid => 'Оплачен',
    OrderStatus.active => 'Активен',
    OrderStatus.completed => 'Завершён',
  };

  static OrderStatus fromWire(String value) => switch (value) {
    'active' => OrderStatus.active,
    'completed' => OrderStatus.completed,
    _ => OrderStatus.paid,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.login,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String login;
  final String fullName;
  final String phone;
  final UserRole role;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String? ?? '',
    login: json['login'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: UserRoleX.fromWire(json['role'] as String? ?? 'client'),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.price,
    required this.stock,
    required this.unitLabel,
    required this.requiresReturn,
    required this.featured,
    required this.tint,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final int price;
  final int stock;
  final String unitLabel;
  final bool requiresReturn;
  final bool featured;
  final String tint;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    category: json['category'] as String? ?? 'general',
    price: (json['price'] as num?)?.toInt() ?? 0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    unitLabel: json['unitLabel'] as String? ?? 'шт',
    requiresReturn: json['requiresReturn'] as bool? ?? false,
    featured: json['featured'] as bool? ?? false,
    tint: json['tint'] as String? ?? '#37E7FF',
  );

  Product copyWith({
    String? title,
    String? subtitle,
    int? price,
    int? stock,
    String? unitLabel,
    bool? requiresReturn,
    bool? featured,
    String? tint,
  }) => Product(
    id: id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    category: category,
    price: price ?? this.price,
    stock: stock ?? this.stock,
    unitLabel: unitLabel ?? this.unitLabel,
    requiresReturn: requiresReturn ?? this.requiresReturn,
    featured: featured ?? this.featured,
    tint: tint ?? this.tint,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'category': category,
    'price': price,
    'stock': stock,
    'unitLabel': unitLabel,
    'requiresReturn': requiresReturn,
    'featured': featured,
    'tint': tint,
  };
}

class CartEntry {
  const CartEntry({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  int get subtotal => product.price * quantity;

  CartEntry copyWith({int? quantity}) =>
      CartEntry(product: product, quantity: quantity ?? this.quantity);
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.requiresReturn,
  });

  final String productId;
  final String title;
  final int quantity;
  final int unitPrice;
  final bool requiresReturn;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    productId: json['productId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
    requiresReturn: json['requiresReturn'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'title': title,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'requiresReturn': requiresReturn,
  };
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryType,
    required this.location,
    required this.paymentMethod,
    required this.paymentMask,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
    this.cylinderSerial,
    this.issuedAt,
    this.returnedAt,
  });

  final String id;
  final String orderCode;
  final String userId;
  final String customerName;
  final String customerPhone;
  final String deliveryType;
  final String location;
  final String paymentMethod;
  final String paymentMask;
  final OrderStatus status;
  final int totalAmount;
  final DateTime createdAt;
  final List<OrderLine> items;
  final String? cylinderSerial;
  final DateTime? issuedAt;
  final DateTime? returnedAt;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    id: json['id'] as String? ?? '',
    orderCode: json['orderCode'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    customerPhone: json['customerPhone'] as String? ?? '',
    deliveryType: json['deliveryType'] as String? ?? 'pickup',
    location: json['location'] as String? ?? '',
    paymentMethod: json['paymentMethod'] as String? ?? 'card',
    paymentMask: json['paymentMask'] as String? ?? '',
    status: OrderStatusX.fromWire(json['status'] as String? ?? 'paid'),
    totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    items: ((json['items'] as List<dynamic>?) ?? const [])
        .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    cylinderSerial: json['cylinderSerial'] as String?,
    issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? ''),
    returnedAt: DateTime.tryParse(json['returnedAt'] as String? ?? ''),
  );
}

class AppConfig {
  const AppConfig({
    required this.promoVideoId,
    required this.safetyVideoId,
    required this.supportPhone,
    required this.brandMessage,
  });

  final String promoVideoId;
  final String safetyVideoId;
  final String supportPhone;
  final String brandMessage;

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    promoVideoId: json['promoVideoId'] as String? ?? 'OjxoHgnaNL8',
    safetyVideoId: json['safetyVideoId'] as String? ?? 'OjxoHgnaNL8',
    supportPhone: json['supportPhone'] as String? ?? '+7 (900) 000-00-00',
    brandMessage:
        json['brandMessage'] as String? ??
        'Собираем заказы без хаоса и ручных конфликтов.',
  );

  factory AppConfig.fallback() => const AppConfig(
    promoVideoId: 'OjxoHgnaNL8',
    safetyVideoId: 'OjxoHgnaNL8',
    supportPhone: '+7 (900) 000-00-00',
    brandMessage: 'Собираем заказы без хаоса и ручных конфликтов.',
  );

  AppConfig copyWith({
    String? promoVideoId,
    String? safetyVideoId,
    String? supportPhone,
    String? brandMessage,
  }) => AppConfig(
    promoVideoId: promoVideoId ?? this.promoVideoId,
    safetyVideoId: safetyVideoId ?? this.safetyVideoId,
    supportPhone: supportPhone ?? this.supportPhone,
    brandMessage: brandMessage ?? this.brandMessage,
  );

  Map<String, dynamic> toJson() => {
    'promoVideoId': promoVideoId,
    'safetyVideoId': safetyVideoId,
    'supportPhone': supportPhone,
    'brandMessage': brandMessage,
  };
}

class DashboardStats {
  const DashboardStats({
    required this.totalRevenue,
    required this.waitingOrders,
    required this.activeOrders,
    required this.lowStockProducts,
  });

  final int totalRevenue;
  final int waitingOrders;
  final int activeOrders;
  final int lowStockProducts;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
    waitingOrders: (json['waitingOrders'] as num?)?.toInt() ?? 0,
    activeOrders: (json['activeOrders'] as num?)?.toInt() ?? 0,
    lowStockProducts: (json['lowStockProducts'] as num?)?.toInt() ?? 0,
  );

  factory DashboardStats.empty() => const DashboardStats(
    totalRevenue: 0,
    waitingOrders: 0,
    activeOrders: 0,
    lowStockProducts: 0,
  );
}
