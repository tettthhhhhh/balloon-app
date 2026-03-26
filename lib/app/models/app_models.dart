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

enum VerificationChannel { email, phone }

extension VerificationChannelX on VerificationChannel {
  String get wireName => switch (this) {
    VerificationChannel.email => 'email',
    VerificationChannel.phone => 'phone',
  };

  String get title => switch (this) {
    VerificationChannel.email => 'Email',
    VerificationChannel.phone => 'Телефон',
  };

  String get helper => switch (this) {
    VerificationChannel.email =>
      'Подтверди email, затем откроется шаг с телефоном.',
    VerificationChannel.phone => 'Подтверди телефон кодом из stub-канала.',
  };

  static VerificationChannel? fromWireOrNull(String? value) => switch (value) {
    'email' => VerificationChannel.email,
    'phone' => VerificationChannel.phone,
    _ => null,
  };
}

enum OrderStatus {
  draft,
  awaitingSignature,
  awaitingPayment,
  paid,
  active,
  completed,
  blocked,
}

extension OrderStatusX on OrderStatus {
  String get wireName => switch (this) {
    OrderStatus.draft => 'draft',
    OrderStatus.awaitingSignature => 'awaiting_signature',
    OrderStatus.awaitingPayment => 'awaiting_payment',
    OrderStatus.paid => 'paid',
    OrderStatus.active => 'active',
    OrderStatus.completed => 'completed',
    OrderStatus.blocked => 'blocked',
  };

  String get title => switch (this) {
    OrderStatus.draft => 'Черновик',
    OrderStatus.awaitingSignature => 'Ждёт подписи',
    OrderStatus.awaitingPayment => 'Ждёт оплаты',
    OrderStatus.paid => 'Оплачен',
    OrderStatus.active => 'Активен',
    OrderStatus.completed => 'Завершён',
    OrderStatus.blocked => 'Заблокирован',
  };

  static OrderStatus fromWire(String value) => switch (value) {
    'draft' => OrderStatus.draft,
    'awaiting_signature' => OrderStatus.awaitingSignature,
    'awaiting_payment' => OrderStatus.awaitingPayment,
    'active' => OrderStatus.active,
    'completed' => OrderStatus.completed,
    'blocked' => OrderStatus.blocked,
    _ => OrderStatus.paid,
  };
}

class PendingVerification {
  const PendingVerification({
    required this.id,
    required this.purpose,
    required this.channel,
    required this.provider,
    required this.targetValue,
    required this.maskedTarget,
    required this.status,
    required this.stubCode,
    required this.attemptCount,
    required this.maxAttempts,
    required this.createdAt,
    this.externalId,
    this.expiresAt,
    this.verifiedAt,
  });

  final String id;
  final String purpose;
  final VerificationChannel channel;
  final String provider;
  final String targetValue;
  final String maskedTarget;
  final String status;
  final String stubCode;
  final int attemptCount;
  final int maxAttempts;
  final DateTime createdAt;
  final String? externalId;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;

  bool get isPending => status == 'pending';

  factory PendingVerification.fromJson(Map<String, dynamic> json) =>
      PendingVerification(
        id: json['id'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        channel:
            VerificationChannelX.fromWireOrNull(json['channel'] as String?) ??
            VerificationChannel.email,
        provider: json['provider'] as String? ?? 'stub-channel',
        targetValue: json['targetValue'] as String? ?? '',
        maskedTarget: json['maskedTarget'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        stubCode: json['stubCode'] as String? ?? '',
        attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
        maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        externalId: json['externalId'] as String?,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
      );
}

class VerificationState {
  const VerificationState({
    required this.required,
    required this.steps,
    this.nextChannel,
    this.currentStep,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
  });

  final bool required;
  final List<PendingVerification> steps;
  final VerificationChannel? nextChannel;
  final PendingVerification? currentStep;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;

  bool get isFullyVerified => !required;

  factory VerificationState.fromJson(Map<String, dynamic> json) {
    final steps = ((json['steps'] as List<dynamic>?) ?? const [])
        .map(
          (item) => PendingVerification.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);

    final currentStepJson = json['currentStep'];
    return VerificationState(
      required: json['required'] as bool? ?? false,
      steps: steps,
      nextChannel: VerificationChannelX.fromWireOrNull(
        json['nextChannel'] as String?,
      ),
      currentStep: currentStepJson is Map<String, dynamic>
          ? PendingVerification.fromJson(currentStepJson)
          : null,
      emailVerifiedAt: DateTime.tryParse(
        json['emailVerifiedAt'] as String? ?? '',
      ),
      phoneVerifiedAt: DateTime.tryParse(
        json['phoneVerifiedAt'] as String? ?? '',
      ),
    );
  }

  factory VerificationState.none() =>
      const VerificationState(required: false, steps: []);
}

class UserRiskSummary {
  const UserRiskSummary({
    required this.canCreateOrders,
    required this.isBlocked,
    required this.overdueActiveOrders,
    required this.overdueOrderCodes,
    required this.maxOverdueDays,
    this.blockCode,
    this.blockReason,
    this.blockSource,
    this.blockedAt,
    this.blockedUntil,
    this.oldestOverdueIssuedAt,
  });

  final bool canCreateOrders;
  final bool isBlocked;
  final int overdueActiveOrders;
  final List<String> overdueOrderCodes;
  final int maxOverdueDays;
  final String? blockCode;
  final String? blockReason;
  final String? blockSource;
  final DateTime? blockedAt;
  final DateTime? blockedUntil;
  final DateTime? oldestOverdueIssuedAt;

  factory UserRiskSummary.fromJson(Map<String, dynamic> json) =>
      UserRiskSummary(
        canCreateOrders: json['canCreateOrders'] as bool? ?? true,
        isBlocked: json['isBlocked'] as bool? ?? false,
        overdueActiveOrders:
            (json['overdueActiveOrders'] as num?)?.toInt() ?? 0,
        overdueOrderCodes:
            ((json['overdueOrderCodes'] as List<dynamic>?) ?? const [])
                .map((item) => '$item')
                .toList(growable: false),
        maxOverdueDays: (json['maxOverdueDays'] as num?)?.toInt() ?? 0,
        blockCode: json['blockCode'] as String?,
        blockReason: json['blockReason'] as String?,
        blockSource: json['blockSource'] as String?,
        blockedAt: DateTime.tryParse(json['blockedAt'] as String? ?? ''),
        blockedUntil: DateTime.tryParse(json['blockedUntil'] as String? ?? ''),
        oldestOverdueIssuedAt: DateTime.tryParse(
          json['oldestOverdueIssuedAt'] as String? ?? '',
        ),
      );

  factory UserRiskSummary.empty() => const UserRiskSummary(
    canCreateOrders: true,
    isBlocked: false,
    overdueActiveOrders: 0,
    overdueOrderCodes: [],
    maxOverdueDays: 0,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.login,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.createdAt,
    required this.risk,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
  });

  final String id;
  final String login;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final UserRiskSummary risk;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;

  bool get isEmailVerified => email.isEmpty || emailVerifiedAt != null;
  bool get isPhoneVerified => phone.isEmpty || phoneVerifiedAt != null;
  bool get isFullyVerified => isEmailVerified && isPhoneVerified;
  bool get canCreateOrders => risk.canCreateOrders;
  bool get isOrderBlocked => risk.isBlocked;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String? ?? '',
    login: json['login'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: UserRoleX.fromWire(json['role'] as String? ?? 'client'),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    risk: json['risk'] is Map<String, dynamic>
        ? UserRiskSummary.fromJson(json['risk'] as Map<String, dynamic>)
        : UserRiskSummary.empty(),
    emailVerifiedAt: DateTime.tryParse(
      json['emailVerifiedAt'] as String? ?? '',
    ),
    phoneVerifiedAt: DateTime.tryParse(
      json['phoneVerifiedAt'] as String? ?? '',
    ),
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
    required this.isVisible,
    required this.tint,
    this.previewImageUrl,
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
  final bool isVisible;
  final String tint;
  final String? previewImageUrl;

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
    isVisible: json['isVisible'] as bool? ?? true,
    tint: json['tint'] as String? ?? '#37E7FF',
    previewImageUrl: json['previewImageUrl'] as String?,
  );

  Product copyWith({
    String? title,
    String? subtitle,
    String? category,
    int? price,
    int? stock,
    String? unitLabel,
    bool? requiresReturn,
    bool? featured,
    bool? isVisible,
    String? tint,
    String? previewImageUrl,
  }) => Product(
    id: id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    category: category ?? this.category,
    price: price ?? this.price,
    stock: stock ?? this.stock,
    unitLabel: unitLabel ?? this.unitLabel,
    requiresReturn: requiresReturn ?? this.requiresReturn,
    featured: featured ?? this.featured,
    isVisible: isVisible ?? this.isVisible,
    tint: tint ?? this.tint,
    previewImageUrl: previewImageUrl ?? this.previewImageUrl,
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
    'isVisible': isVisible,
    'tint': tint,
    'previewImageUrl': previewImageUrl,
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

class CylinderLogModel {
  const CylinderLogModel({
    required this.id,
    required this.orderId,
    required this.serialNumber,
    required this.quantity,
    required this.status,
    required this.createdAt,
    this.orderItemId,
    this.qrCode,
    this.issuedAt,
    this.returnedAt,
  });

  final String id;
  final String orderId;
  final String serialNumber;
  final int quantity;
  final String status;
  final DateTime createdAt;
  final String? orderItemId;
  final String? qrCode;
  final DateTime? issuedAt;
  final DateTime? returnedAt;

  factory CylinderLogModel.fromJson(Map<String, dynamic> json) =>
      CylinderLogModel(
        id: json['id'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        serialNumber: json['serialNumber'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'reserved',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        orderItemId: json['orderItemId'] as String?,
        qrCode: json['qrCode'] as String?,
        issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? ''),
        returnedAt: DateTime.tryParse(json['returnedAt'] as String? ?? ''),
      );
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
    required this.cylinderLogs,
    this.cylinderSerial,
    this.issuedAt,
    this.returnedAt,
    this.contractId,
    this.contractStatus,
    this.contractDocumentUrl,
    this.paymentId,
    this.paymentStatus,
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
  final List<CylinderLogModel> cylinderLogs;
  final String? cylinderSerial;
  final DateTime? issuedAt;
  final DateTime? returnedAt;
  final String? contractId;
  final String? contractStatus;
  final String? contractDocumentUrl;
  final String? paymentId;
  final String? paymentStatus;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  int get returnableCount => items.fold(
    0,
    (sum, item) => sum + (item.requiresReturn ? item.quantity : 0),
  );
  List<CylinderLogModel> get issuedCylinderLogs => cylinderLogs
      .where((log) => log.status == 'issued')
      .toList(growable: false);
  List<CylinderLogModel> get returnedCylinderLogs => cylinderLogs
      .where((log) => log.status == 'returned')
      .toList(growable: false);
  List<String> get issuedSerials => cylinderLogs
      .map((log) => log.serialNumber)
      .where((serial) => serial.isNotEmpty && serial != 'UNASSIGNED')
      .toList(growable: false);

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
    cylinderLogs: ((json['cylinderLogs'] as List<dynamic>?) ?? const [])
        .map((item) => CylinderLogModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    cylinderSerial: json['cylinderSerial'] as String?,
    issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? ''),
    returnedAt: DateTime.tryParse(json['returnedAt'] as String? ?? ''),
    contractId: json['contractId'] as String?,
    contractStatus: json['contractStatus'] as String?,
    contractDocumentUrl: json['contractDocumentUrl'] as String?,
    paymentId: json['paymentId'] as String?,
    paymentStatus: json['paymentStatus'] as String?,
  );
}

class ContractEventModel {
  const ContractEventModel({
    required this.id,
    required this.contractId,
    required this.eventType,
    required this.status,
    required this.createdAt,
    this.payload,
  });

  final String id;
  final String contractId;
  final String eventType;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  factory ContractEventModel.fromJson(Map<String, dynamic> json) =>
      ContractEventModel(
        id: json['id'] as String? ?? '',
        contractId: json['contractId'] as String? ?? '',
        eventType: json['eventType'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        payload: json['payload'] as Map<String, dynamic>?,
      );
}

class ContractModel {
  const ContractModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.provider,
    required this.documentNumber,
    required this.documentTitle,
    required this.documentBody,
    required this.signatureMethod,
    required this.status,
    required this.stubMode,
    required this.createdAt,
    required this.events,
    this.externalId,
    this.fileUrl,
    this.signHash,
    this.userIp,
    this.deviceInfo,
    this.signedAt,
    this.lastEventAt,
  });

  final String id;
  final String orderId;
  final String userId;
  final String provider;
  final String documentNumber;
  final String documentTitle;
  final String documentBody;
  final String signatureMethod;
  final String status;
  final bool stubMode;
  final DateTime createdAt;
  final List<ContractEventModel> events;
  final String? externalId;
  final String? fileUrl;
  final String? signHash;
  final String? userIp;
  final String? deviceInfo;
  final DateTime? signedAt;
  final DateTime? lastEventAt;

  factory ContractModel.fromJson(Map<String, dynamic> json) => ContractModel(
    id: json['id'] as String? ?? '',
    orderId: json['orderId'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    documentNumber: json['documentNumber'] as String? ?? '',
    documentTitle: json['documentTitle'] as String? ?? '',
    documentBody: json['documentBody'] as String? ?? '',
    signatureMethod: json['signatureMethod'] as String? ?? '',
    status: json['status'] as String? ?? '',
    stubMode: json['stubMode'] as bool? ?? true,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    events: ((json['events'] as List<dynamic>?) ?? const [])
        .map(
          (item) => ContractEventModel.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
    externalId: json['externalId'] as String?,
    fileUrl: json['fileUrl'] as String?,
    signHash: json['signHash'] as String?,
    userIp: json['userIp'] as String?,
    deviceInfo: json['deviceInfo'] as String?,
    signedAt: DateTime.tryParse(json['signedAt'] as String? ?? ''),
    lastEventAt: DateTime.tryParse(json['lastEventAt'] as String? ?? ''),
  );
}

class ContractAccessModel {
  const ContractAccessModel({
    required this.contractId,
    required this.previewUrl,
    required this.pdfUrl,
    required this.downloadUrl,
    required this.expiresAt,
  });

  final String contractId;
  final String previewUrl;
  final String pdfUrl;
  final String downloadUrl;
  final DateTime expiresAt;

  factory ContractAccessModel.fromJson(Map<String, dynamic> json) =>
      ContractAccessModel(
        contractId: json['contractId'] as String? ?? '',
        previewUrl: json['previewUrl'] as String? ?? '',
        pdfUrl: json['pdfUrl'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        expiresAt:
            DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class PaymentEventModel {
  const PaymentEventModel({
    required this.id,
    required this.paymentId,
    required this.eventType,
    required this.status,
    required this.createdAt,
    this.amount,
    this.providerEventId,
    this.payload,
  });

  final String id;
  final String paymentId;
  final String eventType;
  final String status;
  final DateTime createdAt;
  final int? amount;
  final String? providerEventId;
  final Map<String, dynamic>? payload;

  factory PaymentEventModel.fromJson(Map<String, dynamic> json) =>
      PaymentEventModel(
        id: json['id'] as String? ?? '',
        paymentId: json['paymentId'] as String? ?? '',
        eventType: json['eventType'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        amount: (json['amount'] as num?)?.toInt(),
        providerEventId: json['providerEventId'] as String?,
        payload: json['payload'] as Map<String, dynamic>?,
      );
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.method,
    required this.status,
    required this.amount,
    required this.currency,
    required this.stubMode,
    required this.createdAt,
    required this.events,
    this.paymentMask,
    this.externalId,
    this.providerReference,
    this.failureReason,
    this.paidAt,
    this.lastEventAt,
  });

  final String id;
  final String orderId;
  final String provider;
  final String method;
  final String status;
  final int amount;
  final String currency;
  final bool stubMode;
  final DateTime createdAt;
  final List<PaymentEventModel> events;
  final String? paymentMask;
  final String? externalId;
  final String? providerReference;
  final String? failureReason;
  final DateTime? paidAt;
  final DateTime? lastEventAt;

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: json['id'] as String? ?? '',
    orderId: json['orderId'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    method: json['method'] as String? ?? '',
    status: json['status'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'RUB',
    stubMode: json['stubMode'] as bool? ?? true,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    events: ((json['events'] as List<dynamic>?) ?? const [])
        .map((item) => PaymentEventModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    paymentMask: json['paymentMask'] as String?,
    externalId: json['externalId'] as String?,
    providerReference: json['providerReference'] as String?,
    failureReason: json['failureReason'] as String?,
    paidAt: DateTime.tryParse(json['paidAt'] as String? ?? ''),
    lastEventAt: DateTime.tryParse(json['lastEventAt'] as String? ?? ''),
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

class ActiveRentalSummary {
  const ActiveRentalSummary({
    required this.orderId,
    required this.orderCode,
    required this.userId,
    required this.userLogin,
    required this.userFullName,
    required this.customerName,
    required this.customerPhone,
    required this.location,
    required this.totalAmount,
    required this.itemCount,
    required this.returnQuantity,
    required this.overdueDays,
    required this.isOverdue,
    required this.cylinderSerials,
    this.issuedAt,
    this.createdAt,
  });

  final String orderId;
  final String orderCode;
  final String userId;
  final String userLogin;
  final String userFullName;
  final String customerName;
  final String customerPhone;
  final String location;
  final int totalAmount;
  final int itemCount;
  final int returnQuantity;
  final int overdueDays;
  final bool isOverdue;
  final List<String> cylinderSerials;
  final DateTime? issuedAt;
  final DateTime? createdAt;

  String? get primarySerial =>
      cylinderSerials.isEmpty ? null : cylinderSerials.first;

  factory ActiveRentalSummary.fromJson(Map<String, dynamic> json) =>
      ActiveRentalSummary(
        orderId: json['orderId'] as String? ?? '',
        orderCode: json['orderCode'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userLogin: json['userLogin'] as String? ?? '',
        userFullName: json['userFullName'] as String? ?? '',
        customerName: json['customerName'] as String? ?? '',
        customerPhone: json['customerPhone'] as String? ?? '',
        location: json['location'] as String? ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        returnQuantity: (json['returnQuantity'] as num?)?.toInt() ?? 0,
        overdueDays: (json['overdueDays'] as num?)?.toInt() ?? 0,
        isOverdue: json['isOverdue'] as bool? ?? false,
        cylinderSerials:
            ((json['cylinderSerials'] as List<dynamic>?) ?? const [])
                .map((item) => '$item')
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
        issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class AdminRiskEvent {
  const AdminRiskEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.status,
    required this.createdAt,
    required this.userLogin,
    required this.userFullName,
    this.orderId,
    this.orderCode,
    this.payload,
  });

  final String id;
  final String userId;
  final String eventType;
  final String status;
  final DateTime createdAt;
  final String userLogin;
  final String userFullName;
  final String? orderId;
  final String? orderCode;
  final Map<String, dynamic>? payload;

  factory AdminRiskEvent.fromJson(Map<String, dynamic> json) => AdminRiskEvent(
    id: json['id'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    eventType: json['eventType'] as String? ?? '',
    status: json['status'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    userLogin: json['userLogin'] as String? ?? '',
    userFullName: json['userFullName'] as String? ?? '',
    orderId: json['orderId'] as String?,
    orderCode: json['orderCode'] as String?,
    payload: json['payload'] as Map<String, dynamic>?,
  );
}

class AdminRiskOverview {
  const AdminRiskOverview({
    required this.users,
    required this.activeRentals,
    required this.events,
  });

  final List<AppUser> users;
  final List<ActiveRentalSummary> activeRentals;
  final List<AdminRiskEvent> events;

  factory AdminRiskOverview.fromJson(Map<String, dynamic> json) =>
      AdminRiskOverview(
        users: ((json['users'] as List<dynamic>?) ?? const [])
            .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        activeRentals: ((json['activeRentals'] as List<dynamic>?) ?? const [])
            .map(
              (item) =>
                  ActiveRentalSummary.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        events: ((json['events'] as List<dynamic>?) ?? const [])
            .map(
              (item) => AdminRiskEvent.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  factory AdminRiskOverview.empty() =>
      const AdminRiskOverview(users: [], activeRentals: [], events: []);
}

class DashboardStats {
  const DashboardStats({
    required this.totalRevenue,
    required this.waitingOrders,
    required this.activeOrders,
    required this.lowStockProducts,
    required this.overdueActiveOrders,
    required this.blockedUsers,
  });

  final int totalRevenue;
  final int waitingOrders;
  final int activeOrders;
  final int lowStockProducts;
  final int overdueActiveOrders;
  final int blockedUsers;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
    waitingOrders: (json['waitingOrders'] as num?)?.toInt() ?? 0,
    activeOrders: (json['activeOrders'] as num?)?.toInt() ?? 0,
    lowStockProducts: (json['lowStockProducts'] as num?)?.toInt() ?? 0,
    overdueActiveOrders: (json['overdueActiveOrders'] as num?)?.toInt() ?? 0,
    blockedUsers: (json['blockedUsers'] as num?)?.toInt() ?? 0,
  );

  factory DashboardStats.empty() => const DashboardStats(
    totalRevenue: 0,
    waitingOrders: 0,
    activeOrders: 0,
    lowStockProducts: 0,
    overdueActiveOrders: 0,
    blockedUsers: 0,
  );
}
