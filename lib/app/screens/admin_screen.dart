import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/contract_access_sheet.dart';
import '../widgets/neon_ui.dart';

enum _AdminUserFilter { all, blocked, overdue }

enum _AdminRentalFilter { all, overdue, withSerials }

enum _AdminEventFilter { all, blocking, returns, adminActions }

enum _AdminOrderFilter {
  all,
  awaitingSignature,
  awaitingPayment,
  paid,
  active,
  overdue,
  completed,
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final TextEditingController _promoController;
  late final TextEditingController _safetyController;
  late final TextEditingController _supportController;
  late final TextEditingController _messageController;
  late final TextEditingController _riskSearchController;
  late final TextEditingController _eventsSearchController;
  late final TextEditingController _ordersSearchController;

  String _riskSearch = '';
  String _eventsSearch = '';
  String _ordersSearch = '';
  _AdminUserFilter _userFilter = _AdminUserFilter.all;
  _AdminRentalFilter _rentalFilter = _AdminRentalFilter.all;
  _AdminEventFilter _eventFilter = _AdminEventFilter.all;
  _AdminOrderFilter _orderFilter = _AdminOrderFilter.all;
  bool _riskControlExpanded = true;
  bool _rentalsExpanded = true;
  bool _eventsExpanded = false;
  bool _ordersExpanded = true;
  bool _catalogExpanded = true;
  bool _configExpanded = false;

  @override
  void initState() {
    super.initState();
    _promoController = TextEditingController();
    _safetyController = TextEditingController();
    _supportController = TextEditingController();
    _messageController = TextEditingController();
    _riskSearchController = TextEditingController();
    _eventsSearchController = TextEditingController();
    _ordersSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _promoController.dispose();
    _safetyController.dispose();
    _supportController.dispose();
    _messageController.dispose();
    _riskSearchController.dispose();
    _eventsSearchController.dispose();
    _ordersSearchController.dispose();
    super.dispose();
  }

  Future<void> _copyText(String text, String successMessage) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: normalized));
    if (!mounted) {
      return;
    }
    showInfoSnackBar(context, successMessage);
  }

  String _buildUsersDigest(List<AppUser> users) {
    if (users.isEmpty) {
      return 'Клиенты не найдены.';
    }
    return users
        .map(
          (user) =>
              '${user.fullName} (@${user.login}) • ${user.phone} • '
              '${user.isOrderBlocked ? 'блок' : 'ok'} • '
              'просрочек ${user.risk.overdueActiveOrders}',
        )
        .join('\n');
  }

  String _buildRentalsDigest(List<ActiveRentalSummary> rentals) {
    if (rentals.isEmpty) {
      return 'Активные аренды не найдены.';
    }
    return rentals
        .map(
          (rental) =>
              '${rental.orderCode} • ${rental.userFullName} • '
              '${rental.customerPhone} • ${rental.overdueDays} дн. • '
              '${rental.cylinderSerials.join(', ')}',
        )
        .join('\n');
  }

  String _buildEventsDigest(List<AdminRiskEvent> events) {
    if (events.isEmpty) {
      return 'События не найдены.';
    }
    return events
        .map(
          (event) =>
              '${_formatDateTime(event.createdAt)} • '
              '${_humanizeRiskEvent(event.eventType)} • '
              '${event.userFullName}'
              '${event.orderCode?.isNotEmpty == true ? ' • ${event.orderCode}' : ''}',
        )
        .join('\n');
  }

  String _buildOrdersDigest(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return 'Заказы не найдены.';
    }
    return orders
        .map(
          (order) =>
              '${order.orderCode} • ${order.status.title} • ${order.customerName} • '
              '${order.customerPhone} • ${rubles(order.totalAmount)}',
        )
        .join('\n');
  }

  String _buildSerialsDigest(List<ActiveRentalSummary> rentals) {
    final serials = <String>{
      for (final rental in rentals) ...rental.cylinderSerials,
    };
    if (serials.isEmpty) {
      return 'Серийники не найдены.';
    }
    return serials.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    _promoController.text = app.config.promoVideoId;
    _safetyController.text = app.config.safetyVideoId;
    _supportController.text = app.config.supportPhone;
    _messageController.text = app.config.brandMessage;
    final blockedUsersCount = app.riskOverview.users
        .where((user) => user.isOrderBlocked)
        .length;
    final overdueRentalsCount = app.riskOverview.activeRentals
        .where((rental) => rental.isOverdue)
        .length;
    final filteredUsers = app.riskOverview.users
        .where(
          (user) => _matchesAdminUser(user, _riskSearch, filter: _userFilter),
        )
        .toList(growable: false);
    final filteredRentals = app.riskOverview.activeRentals
        .where(
          (rental) =>
              _matchesActiveRental(rental, _riskSearch, filter: _rentalFilter),
        )
        .toList(growable: false);
    final filteredEvents = app.riskOverview.events
        .where(
          (event) =>
              _matchesAdminEvent(event, _eventsSearch, filter: _eventFilter),
        )
        .toList(growable: false);
    final filteredOrders = app.orders
        .where(
          (order) =>
              _matchesAdminOrder(order, _ordersSearch, filter: _orderFilter),
        )
        .toList(growable: false);
    final userPreview = filteredUsers.take(3).toList(growable: false);
    final rentalPreview = filteredRentals.take(3).toList(growable: false);
    final eventPreview = filteredEvents.take(3).toList(growable: false);
    final orderPreview = filteredOrders.take(3).toList(growable: false);
    final attentionUsers =
        app.riskOverview.users
            .where(
              (user) =>
                  user.isOrderBlocked || user.risk.overdueActiveOrders > 0,
            )
            .toList()
          ..sort(
            (left, right) => right.risk.overdueActiveOrders.compareTo(
              left.risk.overdueActiveOrders,
            ),
          );
    final attentionRentals =
        app.riskOverview.activeRentals
            .where(
              (rental) => rental.isOverdue || rental.cylinderSerials.isNotEmpty,
            )
            .toList()
          ..sort(
            (left, right) => right.overdueDays.compareTo(left.overdueDays),
          );
    final recentOrders = [...app.orders]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final recentOrdersPreview = recentOrders.take(5).toList(growable: false);
    final awaitingSignatureCount = app.orders
        .where((order) => order.status == OrderStatus.awaitingSignature)
        .length;
    final awaitingPaymentCount = app.orders
        .where((order) => order.status == OrderStatus.awaitingPayment)
        .length;
    final readyToIssueCount = app.orders
        .where((order) => order.status == OrderStatus.paid)
        .length;
    final completedOrdersCount = app.orders
        .where((order) => order.status == OrderStatus.completed)
        .length;
    final verifiedUsersCount = app.riskOverview.users
        .where((user) => user.isFullyVerified)
        .length;
    final hiddenProductsCount = app.products
        .where((product) => !product.isVisible)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        actions: [
          IconButton(
            onPressed: () async {
              await app.refreshPublicData();
              await app.refreshOrders();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: app.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(
                  eyebrow: 'Control room',
                  title: 'Статусы, склад, конфиг и события',
                  subtitle:
                      'Админ теперь видит не только метрики и товары, но и цепочку договора и платежа по каждому заказу.',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Выручка',
                        value: rubles(app.dashboard.totalRevenue),
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Ждут выдачи',
                        value: '${app.dashboard.waitingOrders}',
                        color: AppPalette.rose,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Активные',
                        value: '${app.dashboard.activeOrders}',
                        color: AppPalette.gold,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Низкий остаток',
                        value: '${app.dashboard.lowStockProducts}',
                        color: AppPalette.danger,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Просрочка',
                        value: '${app.dashboard.overdueActiveOrders}',
                        color: AppPalette.peach,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Блокировки',
                        value: '${app.dashboard.blockedUsers}',
                        color: AppPalette.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Клиенты',
                        value: '${app.riskOverview.users.length}',
                        color: AppPalette.mint,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Верифицированы',
                        value: '$verifiedUsersCount',
                        color: AppPalette.mint,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Ждут подписи',
                        value: '$awaitingSignatureCount',
                        color: AppPalette.gold,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Ждут оплаты',
                        value: '$awaitingPaymentCount',
                        color: AppPalette.peach,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Завершено',
                        value: '$completedOrdersCount',
                        color: AppPalette.mint,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Скрыто с витрины',
                        value: '$hiddenProductsCount',
                        color: AppPalette.plum,
                      ),
                    ),
                  ],
                ),
                if (recentOrdersPreview.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _AdminSearchPanel(
                    eyebrow: 'Recent activity',
                    title: 'Последние заказы и клиенты',
                    subtitle:
                        'Здесь быстро видно, кто именно заказывал, на какой стадии его заказ и какая сумма в обработке.',
                    child: Column(
                      children: [
                        for (final order in recentOrdersPreview) ...[
                          _RecentOrderTile(
                            order: order,
                            onOpen: () => _showOrderFlow(context, app, order),
                          ),
                          if (order != recentOrdersPreview.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _AdminSearchPanel(
                  eyebrow: 'Quick focus',
                  title: 'Быстрые срезы по проблемам и стадиям',
                  subtitle:
                      'Один тап, чтобы сфокусироваться на блокировках, просрочке или заказах, которые сейчас ждут действия.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.block_rounded,
                          size: 18,
                          color: AppPalette.danger,
                        ),
                        label: Text('Блокировки $blockedUsersCount'),
                        onPressed: () {
                          setState(() {
                            _userFilter = _AdminUserFilter.blocked;
                            _riskSearch = '';
                            _riskSearchController.clear();
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppPalette.peach,
                        ),
                        label: Text('Просрочка $overdueRentalsCount'),
                        onPressed: () {
                          setState(() {
                            _rentalFilter = _AdminRentalFilter.overdue;
                            _orderFilter = _AdminOrderFilter.overdue;
                            _ordersSearch = '';
                            _ordersSearchController.clear();
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: AppPalette.rose,
                        ),
                        label: Text(
                          'Ждут выдачи ${app.orders.where((order) => order.status == OrderStatus.paid).length}',
                        ),
                        onPressed: () {
                          setState(() {
                            _orderFilter = _AdminOrderFilter.paid;
                            _ordersSearch = '';
                            _ordersSearchController.clear();
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.draw_rounded,
                          size: 18,
                          color: AppPalette.gold,
                        ),
                        label: Text(
                          'Ждут подписи ${app.orders.where((order) => order.status == OrderStatus.awaitingSignature).length}',
                        ),
                        onPressed: () {
                          setState(() {
                            _orderFilter = _AdminOrderFilter.awaitingSignature;
                            _ordersSearch = '';
                            _ordersSearchController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (attentionUsers.isNotEmpty || attentionRentals.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Attention center',
                    title: 'Требует внимания прямо сейчас',
                    subtitle:
                        'Самые горячие кейсы вынесены наверх: кого блокирует риск и какие аренды уже пора разбирать без промедления.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (attentionUsers.isNotEmpty)
                        _AttentionCard(
                          icon: Icons.person_off_rounded,
                          color: AppPalette.danger,
                          title: 'Клиенты под риском',
                          subtitle:
                              '${attentionUsers.first.fullName} • просрочек ${attentionUsers.first.risk.overdueActiveOrders}',
                          caption:
                              'Всего ${attentionUsers.length} проблемных клиентов',
                          onTap: () {
                            setState(() {
                              _userFilter = _AdminUserFilter.blocked;
                              _riskSearch = '';
                              _riskSearchController.clear();
                            });
                          },
                          actionLabel: 'Открыть блокировки',
                        ),
                      if (attentionRentals.isNotEmpty)
                        _AttentionCard(
                          icon: Icons.inventory_2_outlined,
                          color: AppPalette.peach,
                          title: 'Просроченная аренда',
                          subtitle:
                              '${attentionRentals.first.orderCode} • ${attentionRentals.first.overdueDays} дн.',
                          caption:
                              '${attentionRentals.first.userFullName} • ${attentionRentals.first.customerPhone}',
                          onTap: () {
                            setState(() {
                              _rentalFilter = _AdminRentalFilter.overdue;
                              _orderFilter = _AdminOrderFilter.overdue;
                            });
                          },
                          actionLabel: 'Открыть просрочку',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _AdminSectionToggleCard(
            eyebrow: 'Risk control',
            title: 'Клиенты, аренды и ограничения',
            subtitle:
                'Показано ${filteredUsers.length} из ${app.riskOverview.users.length} клиентов. Фильтры ниже помогают быстро собрать проблемные кейсы.',
            expanded: _riskControlExpanded,
            onToggle: () =>
                setState(() => _riskControlExpanded = !_riskControlExpanded),
            trailing: StatusBadge(
              label: 'Блокировки $blockedUsersCount',
              color: blockedUsersCount > 0
                  ? AppPalette.danger
                  : AppPalette.mint,
            ),
          ),
          if (!_riskControlExpanded) ...[
            const SizedBox(height: 12),
            _AdminCollapsedPreviewPanel(
              eyebrow: 'Quick preview',
              title: 'Клиенты в фокусе',
              subtitle: filteredUsers.isEmpty
                  ? 'По текущим фильтрам список пуст. Разверни секцию, чтобы изменить фильтры или посмотреть полный блок.'
                  : 'Показываем ${userPreview.length} из ${filteredUsers.length} клиентов, чтобы не растягивать экран.',
              actionLabel: 'Показать все',
              onAction: () => setState(() => _riskControlExpanded = true),
              child: filteredUsers.isEmpty
                  ? const EmptyStatePanel(
                      title: 'Сейчас пусто',
                      message:
                          'Разверни секцию риска, чтобы быстро поменять фильтры и посмотреть полный список клиентов.',
                      icon: Icons.filter_alt_off_rounded,
                    )
                  : Column(
                      children: [
                        for (final user in userPreview) ...[
                          _CollapsedUserPreviewTile(user: user),
                          if (user != userPreview.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _AdminSearchPanel(
              eyebrow: 'Client filters',
              title: 'Поиск по клиентам и активной таре',
              subtitle:
                  'Ищи по имени, логину, телефону, email, коду заказа или серийнику. Ниже можно зажать только блокировки или просрочку.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _riskSearchController,
                    onChanged: (value) => setState(() => _riskSearch = value),
                    decoration: const InputDecoration(
                      labelText: 'Поиск по клиентам и арендам',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Все клиенты'),
                        selected: _userFilter == _AdminUserFilter.all,
                        onSelected: (_) =>
                            setState(() => _userFilter = _AdminUserFilter.all),
                      ),
                      FilterChip(
                        label: Text('Только блок $blockedUsersCount'),
                        selected: _userFilter == _AdminUserFilter.blocked,
                        onSelected: (_) => setState(
                          () => _userFilter = _AdminUserFilter.blocked,
                        ),
                      ),
                      FilterChip(
                        label: Text(
                          'С просрочкой ${app.riskOverview.users.where((user) => user.risk.overdueActiveOrders > 0).length}',
                        ),
                        selected: _userFilter == _AdminUserFilter.overdue,
                        onSelected: (_) => setState(
                          () => _userFilter = _AdminUserFilter.overdue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: filteredUsers.isEmpty
                            ? null
                            : () => _copyText(
                                _buildUsersDigest(filteredUsers),
                                'Сводка по клиентам скопирована.',
                              ),
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Копировать срез'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _riskSearch = '';
                            _riskSearchController.clear();
                            _userFilter = _AdminUserFilter.all;
                            _rentalFilter = _AdminRentalFilter.all;
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: const Text('Сбросить фильтры'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: filteredEvents.isEmpty
                            ? null
                            : () => _copyText(
                                _buildEventsDigest(filteredEvents),
                                'Журнал событий скопирован.',
                              ),
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Копировать журнал'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _eventsSearch = '';
                            _eventsSearchController.clear();
                            _eventFilter = _AdminEventFilter.all;
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: const Text('Сбросить фильтры'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: filteredOrders.isEmpty
                            ? null
                            : () => _copyText(
                                _buildOrdersDigest(filteredOrders),
                                'Сводка по заказам скопирована.',
                              ),
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Копировать срез'),
                      ),
                      OutlinedButton.icon(
                        onPressed: filteredOrders.isEmpty
                            ? null
                            : () => _copyText(
                                filteredOrders
                                    .map((order) => order.orderCode)
                                    .join('\n'),
                                'Коды заказов скопированы.',
                              ),
                        icon: const Icon(Icons.tag_rounded),
                        label: const Text('Копировать коды'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _ordersSearch = '';
                            _ordersSearchController.clear();
                            _orderFilter = _AdminOrderFilter.all;
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: const Text('Сбросить фильтры'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (app.riskOverview.users.isEmpty)
              const EmptyStatePanel(
                title: 'Клиентов пока нет',
                message:
                    'После первых регистраций здесь появятся карточки клиентов, активные аренды и журнал risk events.',
                icon: Icons.verified_user_outlined,
              )
            else ...[
              if (filteredUsers.isEmpty)
                const EmptyStatePanel(
                  title: 'Ничего не найдено',
                  message:
                      'Попробуй снять часть фильтров или изменить строку поиска по клиентам.',
                  icon: Icons.filter_alt_off_rounded,
                )
              else
                ...filteredUsers.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${user.login} • ${user.phone}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.62,
                                        ),
                                      ),
                                    ),
                                    if (user.email.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.48,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              StatusBadge(
                                label: user.isOrderBlocked ? 'Блок' : 'Ок',
                                color: user.isOrderBlocked
                                    ? AppPalette.danger
                                    : AppPalette.mint,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              StatusBadge(
                                label:
                                    'Просрочек ${user.risk.overdueActiveOrders}',
                                color: user.risk.overdueActiveOrders > 0
                                    ? AppPalette.peach
                                    : AppPalette.mint,
                              ),
                              if (user.risk.blockSource != null)
                                StatusBadge(
                                  label: user.risk.blockSource == 'manual'
                                      ? 'Ручной блок'
                                      : 'Автоблок',
                                  color: user.risk.blockSource == 'manual'
                                      ? AppPalette.plum
                                      : AppPalette.danger,
                                ),
                              if (user.risk.maxOverdueDays > 0)
                                StatusBadge(
                                  label:
                                      'До ${user.risk.maxOverdueDays} дн. просрочки',
                                  color: AppPalette.gold,
                                ),
                            ],
                          ),
                          if (user.risk.blockReason?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            Text(
                              user.risk.blockReason!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (user.risk.blockedUntil != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'До: ${_formatDateTime(user.risk.blockedUntil)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: user.isOrderBlocked
                                    ? () => _showUnblockUserDialog(
                                        context,
                                        app,
                                        user,
                                      )
                                    : () => _showBlockUserDialog(
                                        context,
                                        app,
                                        user,
                                      ),
                                icon: Icon(
                                  user.isOrderBlocked
                                      ? Icons.lock_open_rounded
                                      : Icons.block_rounded,
                                ),
                                label: Text(
                                  user.isOrderBlocked
                                      ? 'Снять блок'
                                      : 'Ограничить',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _copyText(
                                  _buildUsersDigest([user]),
                                  'Карточка клиента скопирована.',
                                ),
                                icon: const Icon(Icons.content_copy_rounded),
                                label: const Text('Копировать'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _AdminSectionToggleCard(
                eyebrow: 'Active rentals',
                title: 'Активные аренды с возвратной тарой',
                subtitle:
                    'Показано ${filteredRentals.length} из ${app.riskOverview.activeRentals.length} активных аренд. Можно быстро отделить просрочку от обычной выдачи.',
                expanded: _rentalsExpanded,
                onToggle: () =>
                    setState(() => _rentalsExpanded = !_rentalsExpanded),
                trailing: StatusBadge(
                  label: 'Просрочка $overdueRentalsCount',
                  color: overdueRentalsCount > 0
                      ? AppPalette.danger
                      : AppPalette.mint,
                ),
              ),
              if (!_rentalsExpanded) ...[
                const SizedBox(height: 12),
                _AdminCollapsedPreviewPanel(
                  eyebrow: 'Quick preview',
                  title: 'Что сейчас в аренде',
                  subtitle: filteredRentals.isEmpty
                      ? 'Активных аренд по текущему срезу не найдено. Разверни блок, чтобы сменить фильтры.'
                      : 'Показываем ${rentalPreview.length} из ${filteredRentals.length} аренд, чтобы экран не уходил вниз.',
                  actionLabel: 'Показать все',
                  onAction: () => setState(() => _rentalsExpanded = true),
                  child: filteredRentals.isEmpty
                      ? const EmptyStatePanel(
                          title: 'Аренд нет',
                          message:
                              'Разверни секцию, если нужно сменить фильтр или открыть полный список выдач.',
                          icon: Icons.inventory_2_outlined,
                        )
                      : Column(
                          children: [
                            for (final rental in rentalPreview) ...[
                              _CollapsedRentalPreviewTile(rental: rental),
                              if (rental != rentalPreview.last)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _AdminSearchPanel(
                  eyebrow: 'Rental filters',
                  title: 'Срез по возвратной таре',
                  subtitle:
                      'Оставь только просрочку, аренды с серийниками или все активные выдачи. Поиск выше уже тоже применяется.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Все аренды'),
                            selected: _rentalFilter == _AdminRentalFilter.all,
                            onSelected: (_) => setState(
                              () => _rentalFilter = _AdminRentalFilter.all,
                            ),
                          ),
                          FilterChip(
                            label: Text('Просрочка $overdueRentalsCount'),
                            selected:
                                _rentalFilter == _AdminRentalFilter.overdue,
                            onSelected: (_) => setState(
                              () => _rentalFilter = _AdminRentalFilter.overdue,
                            ),
                          ),
                          FilterChip(
                            label: Text(
                              'Есть серийники ${app.riskOverview.activeRentals.where((rental) => rental.cylinderSerials.isNotEmpty).length}',
                            ),
                            selected:
                                _rentalFilter == _AdminRentalFilter.withSerials,
                            onSelected: (_) => setState(
                              () => _rentalFilter =
                                  _AdminRentalFilter.withSerials,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: filteredRentals.isEmpty
                                ? null
                                : () => _copyText(
                                    _buildRentalsDigest(filteredRentals),
                                    'Сводка по арендам скопирована.',
                                  ),
                            icon: const Icon(Icons.inventory_rounded),
                            label: const Text('Копировать аренды'),
                          ),
                          OutlinedButton.icon(
                            onPressed: filteredRentals.isEmpty
                                ? null
                                : () => _copyText(
                                    _buildSerialsDigest(filteredRentals),
                                    'Серийники скопированы.',
                                  ),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text('Копировать серийники'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (app.riskOverview.activeRentals.isEmpty)
                  const EmptyStatePanel(
                    title: 'Активных аренд нет',
                    message:
                        'После выдачи возвратной тары здесь появятся заказы с issuedAt, серийником и количеством возвратных позиций.',
                    icon: Icons.inventory_2_outlined,
                  )
                else if (filteredRentals.isEmpty)
                  const EmptyStatePanel(
                    title: 'Аренды не найдены',
                    message:
                        'По выбранным фильтрам и поиску сейчас нет активных аренд.',
                    icon: Icons.filter_alt_off_rounded,
                  )
                else
                  ...filteredRentals.map(
                    (rental) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rental.orderCode,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                StatusBadge(
                                  label: rental.isOverdue
                                      ? 'Просрочка'
                                      : 'В аренде',
                                  color: rental.isOverdue
                                      ? AppPalette.danger
                                      : AppPalette.gold,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${rental.userFullName} • ${rental.customerPhone}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rental.location,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                            ),
                            if (rental.issuedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Выдано: ${_formatDateTime(rental.issuedAt)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.52),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                StatusBadge(
                                  label:
                                      'Возвратных позиций ${rental.returnQuantity}',
                                  color: AppPalette.rose,
                                ),
                                StatusBadge(
                                  label: 'В аренде ${rental.overdueDays} дн.',
                                  color: rental.isOverdue
                                      ? AppPalette.danger
                                      : AppPalette.peach,
                                ),
                                if (rental.cylinderSerials.isNotEmpty)
                                  StatusBadge(
                                    label:
                                        'Серийников ${rental.cylinderSerials.length}',
                                    color: AppPalette.mint,
                                  ),
                                StatusBadge(
                                  label: rubles(rental.totalAmount),
                                  color: AppPalette.plum,
                                ),
                              ],
                            ),
                            if (rental.cylinderSerials.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _RentalCodesPanel(
                                title: 'Выданные серийники',
                                codes: rental.cylinderSerials,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final order = _findOrderById(
                                      app.orders,
                                      rental.orderId,
                                    );
                                    if (order == null) {
                                      showInfoSnackBar(
                                        context,
                                        'Не удалось найти заказ в текущем списке.',
                                      );
                                      return;
                                    }
                                    _showOrderFlow(context, app, order);
                                  },
                                  icon: const Icon(Icons.timeline_rounded),
                                  label: const Text('Детали заказа'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _copyText(
                                    rental.cylinderSerials.join('\n'),
                                    'Серийники аренды скопированы.',
                                  ),
                                  icon: const Icon(Icons.qr_code_2_rounded),
                                  label: const Text('Копировать коды'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _showForceCompleteDialog(
                                    context,
                                    app,
                                    rental,
                                  ),
                                  icon: const Icon(Icons.assignment_turned_in),
                                  label: const Text('Закрыть аренду'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              _AdminSectionToggleCard(
                eyebrow: 'Risk events',
                title: 'Журнал ограничений и возвратов',
                subtitle:
                    'Показано ${filteredEvents.length} из ${app.riskOverview.events.length} событий. Можно оставить только блокировки, возвраты или действия администратора.',
                expanded: _eventsExpanded,
                onToggle: () =>
                    setState(() => _eventsExpanded = !_eventsExpanded),
                trailing: StatusBadge(
                  label: 'Событий ${app.riskOverview.events.length}',
                  color: app.riskOverview.events.isNotEmpty
                      ? AppPalette.plum
                      : AppPalette.mint,
                ),
              ),
              if (!_eventsExpanded) ...[
                const SizedBox(height: 12),
                _AdminCollapsedPreviewPanel(
                  eyebrow: 'Quick preview',
                  title: 'Последние события',
                  subtitle: filteredEvents.isEmpty
                      ? 'Журнал по текущему фильтру пуст. Разверни секцию, чтобы посмотреть весь поток или сменить фильтр.'
                      : 'Показываем ${eventPreview.length} из ${filteredEvents.length} событий, чтобы журнал не занимал весь экран.',
                  actionLabel: 'Показать все',
                  onAction: () => setState(() => _eventsExpanded = true),
                  child: filteredEvents.isEmpty
                      ? const EmptyStatePanel(
                          title: 'Событий нет',
                          message:
                              'Разверни журнал, чтобы сменить фильтр или посмотреть все события по рискам и возвратам.',
                          icon: Icons.history_rounded,
                        )
                      : Column(
                          children: [
                            for (final event in eventPreview) ...[
                              _CollapsedEventPreviewTile(event: event),
                              if (event != eventPreview.last)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _AdminSearchPanel(
                  eyebrow: 'Event filters',
                  title: 'Быстрый разбор журнала',
                  subtitle:
                      'Поиск ловит пользователя, логин, код заказа и текст payload. Это удобно, когда ищешь конкретный инцидент.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _eventsSearchController,
                        onChanged: (value) =>
                            setState(() => _eventsSearch = value),
                        decoration: const InputDecoration(
                          labelText: 'Поиск по журналу событий',
                          prefixIcon: Icon(Icons.history_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Все события'),
                            selected: _eventFilter == _AdminEventFilter.all,
                            onSelected: (_) => setState(
                              () => _eventFilter = _AdminEventFilter.all,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Блокировки'),
                            selected:
                                _eventFilter == _AdminEventFilter.blocking,
                            onSelected: (_) => setState(
                              () => _eventFilter = _AdminEventFilter.blocking,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Возвраты'),
                            selected: _eventFilter == _AdminEventFilter.returns,
                            onSelected: (_) => setState(
                              () => _eventFilter = _AdminEventFilter.returns,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Действия админа'),
                            selected:
                                _eventFilter == _AdminEventFilter.adminActions,
                            onSelected: (_) => setState(
                              () =>
                                  _eventFilter = _AdminEventFilter.adminActions,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (app.riskOverview.events.isEmpty)
                  const EmptyStatePanel(
                    title: 'Событий пока нет',
                    message:
                        'После первой просрочки, ручной блокировки или force-close здесь появится журнал изменений.',
                    icon: Icons.history_rounded,
                  )
                else if (filteredEvents.isEmpty)
                  const EmptyStatePanel(
                    title: 'События не найдены',
                    message:
                        'Попробуй убрать часть фильтров или изменить поисковый запрос по журналу.',
                    icon: Icons.filter_alt_off_rounded,
                  )
                else
                  ...filteredEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _humanizeRiskEvent(event.eventType),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                StatusBadge(
                                  label: _humanizeFlowStatus(event.status),
                                  color: event.status == 'blocked'
                                      ? AppPalette.danger
                                      : event.status == 'returned'
                                      ? AppPalette.mint
                                      : AppPalette.peach,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${event.userFullName} • @${event.userLogin}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                              ),
                            ),
                            if (event.orderCode?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Заказ: ${event.orderCode}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              _formatDateTime(event.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                              ),
                            ),
                            if (event.payload?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              Text(
                                _formatEventPayload(event.payload),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (event.orderId != null &&
                                _findOrderById(app.orders, event.orderId!) !=
                                    null) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showOrderFlow(
                                      context,
                                      app,
                                      _findOrderById(
                                        app.orders,
                                        event.orderId!,
                                      )!,
                                    ),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('Открыть заказ'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _copyText(
                                      _buildEventsDigest([event]),
                                      'Событие скопировано.',
                                    ),
                                    icon: const Icon(
                                      Icons.content_copy_rounded,
                                    ),
                                    label: const Text('Копировать'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
          const SizedBox(height: 8),
          _AdminSectionToggleCard(
            eyebrow: 'Order flow',
            title: 'Заказы и события',
            subtitle:
                'Показано ${filteredOrders.length} из ${app.orders.length} заказов. Можно быстро оставить нужную стадию или найти заказ по клиенту, адресу и коду.',
            expanded: _ordersExpanded,
            onToggle: () => setState(() => _ordersExpanded = !_ordersExpanded),
            trailing: StatusBadge(
              label: 'К выдаче $readyToIssueCount',
              color: readyToIssueCount > 0 ? AppPalette.peach : AppPalette.mint,
            ),
          ),
          if (!_ordersExpanded) ...[
            const SizedBox(height: 12),
            _AdminCollapsedPreviewPanel(
              eyebrow: 'Quick preview',
              title: 'Последние заказы по фильтру',
              subtitle: filteredOrders.isEmpty
                  ? 'Список заказов по текущему фильтру пуст. Разверни блок, чтобы сменить фильтр или увидеть весь поток.'
                  : 'Показываем ${orderPreview.length} из ${filteredOrders.length} заказов, чтобы блок оставался компактным.',
              actionLabel: 'Показать все',
              onAction: () => setState(() => _ordersExpanded = true),
              child: filteredOrders.isEmpty
                  ? const EmptyStatePanel(
                      title: 'Заказов нет',
                      message:
                          'Разверни секцию, если нужно сменить фильтр или открыть все карточки заказов.',
                      icon: Icons.receipt_long_outlined,
                    )
                  : Column(
                      children: [
                        for (final order in orderPreview) ...[
                          _CollapsedOrderPreviewTile(order: order),
                          if (order != orderPreview.last)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _AdminSearchPanel(
              eyebrow: 'Order filters',
              title: 'Быстрый поиск по всем заказам',
              subtitle:
                  'Полезно для разбора конкретного кейса: поиск ловит код, клиента, телефон, адрес и даже выданные серийники.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ordersSearchController,
                    onChanged: (value) => setState(() => _ordersSearch = value),
                    decoration: const InputDecoration(
                      labelText: 'Поиск по заказам',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Все'),
                        selected: _orderFilter == _AdminOrderFilter.all,
                        onSelected: (_) => setState(
                          () => _orderFilter = _AdminOrderFilter.all,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Подпись'),
                        selected:
                            _orderFilter == _AdminOrderFilter.awaitingSignature,
                        onSelected: (_) => setState(
                          () => _orderFilter =
                              _AdminOrderFilter.awaitingSignature,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Оплата'),
                        selected:
                            _orderFilter == _AdminOrderFilter.awaitingPayment,
                        onSelected: (_) => setState(
                          () =>
                              _orderFilter = _AdminOrderFilter.awaitingPayment,
                        ),
                      ),
                      FilterChip(
                        label: const Text('К выдаче'),
                        selected: _orderFilter == _AdminOrderFilter.paid,
                        onSelected: (_) => setState(
                          () => _orderFilter = _AdminOrderFilter.paid,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Активные'),
                        selected: _orderFilter == _AdminOrderFilter.active,
                        onSelected: (_) => setState(
                          () => _orderFilter = _AdminOrderFilter.active,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Просрочка'),
                        selected: _orderFilter == _AdminOrderFilter.overdue,
                        onSelected: (_) => setState(
                          () => _orderFilter = _AdminOrderFilter.overdue,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Завершённые'),
                        selected: _orderFilter == _AdminOrderFilter.completed,
                        onSelected: (_) => setState(
                          () => _orderFilter = _AdminOrderFilter.completed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (app.orders.isEmpty)
              const EmptyStatePanel(
                title: 'Заказов пока нет',
                message:
                    'После оформления и оплаты здесь появятся статусы, contract events и payment events.',
                icon: Icons.receipt_long_outlined,
              )
            else if (filteredOrders.isEmpty)
              const EmptyStatePanel(
                title: 'Заказы не найдены',
                message:
                    'По выбранным фильтрам сейчас нет заказов. Попробуй снять часть ограничений.',
                icon: Icons.filter_alt_off_rounded,
              )
            else
              ...filteredOrders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.orderCode,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: order.status.title,
                              color: _statusColor(order.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${order.customerName} • ${rubles(order.totalAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.location,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.64),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (order.contractStatus != null)
                              StatusBadge(
                                label:
                                    'Договор ${_humanizeFlowStatus(order.contractStatus!)}',
                                color: order.contractStatus == 'signed'
                                    ? AppPalette.gold
                                    : order.contractStatus == 'rejected'
                                    ? AppPalette.danger
                                    : AppPalette.peach,
                              ),
                            if (order.paymentStatus != null)
                              StatusBadge(
                                label:
                                    'Платёж ${_humanizeFlowStatus(order.paymentStatus!)}',
                                color: order.paymentStatus == 'paid'
                                    ? AppPalette.rose
                                    : order.paymentStatus == 'failed'
                                    ? AppPalette.danger
                                    : AppPalette.peach,
                              ),
                            StatusBadge(
                              label: order.deliveryType == 'pickup'
                                  ? 'Самовывоз'
                                  : 'Доставка',
                              color: AppPalette.mint,
                            ),
                            if (_isOverdueReturnOrder(order))
                              const StatusBadge(
                                label: 'Просроченный возврат',
                                color: AppPalette.danger,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showOrderFlow(context, app, order),
                              icon: const Icon(Icons.timeline_rounded),
                              label: const Text('Открыть flow заказа'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _copyText(
                                '${order.orderCode}\n${order.customerName}\n${order.customerPhone}\n${order.location}',
                                'Карточка заказа скопирована.',
                              ),
                              icon: const Icon(Icons.content_copy_rounded),
                              label: const Text('Копировать'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          _AdminSectionToggleCard(
            eyebrow: 'Catalog admin',
            title: 'Товары и остатки',
            subtitle:
                'Скрывай товар от клиента, не обнуляя остаток, и держи каталог в более понятном виде.',
            expanded: _catalogExpanded,
            onToggle: () =>
                setState(() => _catalogExpanded = !_catalogExpanded),
            trailing: StatusBadge(
              label: 'Скрыто $hiddenProductsCount',
              color: hiddenProductsCount > 0
                  ? AppPalette.plum
                  : AppPalette.mint,
            ),
          ),
          if (_catalogExpanded) ...[
            const SizedBox(height: 12),
            for (final product in app.products) ...[
              _AdminProductCard(
                product: product,
                onEdit: () => _editProductSmart(context, app, product),
              ),
              if (product != app.products.last) const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),
          _AdminSectionToggleCard(
            eyebrow: 'Config',
            title: 'Настройки приложения',
            subtitle:
                'Видео, контакты и бренд-сообщение вынесены отдельно, чтобы не мешать работе с заказами.',
            expanded: _configExpanded,
            onToggle: () => setState(() => _configExpanded = !_configExpanded),
          ),
          if (_configExpanded) ...[
            const SizedBox(height: 12),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _promoController,
                    decoration: const InputDecoration(
                      labelText: 'Promo video ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _safetyController,
                    decoration: const InputDecoration(
                      labelText: 'Safety video ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supportController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон поддержки',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Сообщение на главном экране',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await app.updateConfig(
                          app.config.copyWith(
                            promoVideoId: _promoController.text.trim(),
                            safetyVideoId: _safetyController.text.trim(),
                            supportPhone: _supportController.text.trim(),
                            brandMessage: _messageController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Сохранить конфиг'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          /*
            const SectionHeading(
              eyebrow: 'Catalog admin',
              title: 'Товары и остатки',
            ),
            const SizedBox(height: 12),
            ...app.products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${rubles(product.price)} • остаток ${product.stock} ${product.unitLabel}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.66),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _editProduct(context, app, product),
                        child: const Text('Изменить'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Config',
                    title: 'Настройки приложения',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promoController,
                    decoration: const InputDecoration(
                      labelText: 'Promo video ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _safetyController,
                    decoration: const InputDecoration(
                      labelText: 'Safety video ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supportController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон поддержки',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Сообщение на главном экране',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await app.updateConfig(
                          app.config.copyWith(
                            promoVideoId: _promoController.text.trim(),
                            safetyVideoId: _safetyController.text.trim(),
                            supportPhone: _supportController.text.trim(),
                            brandMessage: _messageController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Сохранить конфиг'),
                    ),
                  ),
                ],
              ),
            ),
          */
        ],
      ),
    );
  }

  Future<void> _showOrderFlow(
    BuildContext context,
    AppController app,
    OrderModel order,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        return FutureBuilder<({ContractModel contract, PaymentModel payment})>(
          future: () async {
            final contract = await app.getOrderContract(order.id);
            final payment = await app.getOrderPayment(order.id);
            return (contract: contract, payment: payment);
          }(),
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: AppSheetShell(
                accentColor: AppPalette.gold,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 720),
                  child: AnimatedSwitcher(
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 220),
                    ),
                    child: snapshot.connectionState != ConnectionState.done
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: LoadingStatePanel(
                              eyebrow: 'Order flow',
                              title: 'Подтягиваем статусы заказа',
                              subtitle:
                                  'Собираем договор, оплату и события, чтобы показать полный operational timeline.',
                            ),
                          )
                        : snapshot.hasError
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyStatePanel(
                              title: 'Flow пока недоступен',
                              message: presentAppError(
                                snapshot.error!,
                                fallback:
                                    'Не удалось загрузить детали заказа. Попробуйте ещё раз чуть позже.',
                              ),
                              icon: Icons.timeline_rounded,
                            ),
                          )
                        : _OrderFlowDetails(
                            key: ValueKey<String>(order.id),
                            app: app,
                            order: order,
                            contract: snapshot.data!.contract,
                            payment: snapshot.data!.payment,
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBlockUserDialog(
    BuildContext context,
    AppController app,
    AppUser user,
  ) async {
    final reasonController = TextEditingController(
      text: user.risk.blockReason?.trim().isNotEmpty == true
          ? user.risk.blockReason
          : 'Ручная блокировка до выяснения деталей по возвратной таре.',
    );
    int? blockedDays = 7;

    await showAppDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AppDialogShell(
              eyebrow: 'Risk control',
              title: 'Ограничить ${user.fullName}',
              subtitle:
                  'Клиент не сможет оформлять новые заказы до снятия ручного блока или окончания срока.',
              icon: Icons.lock_person_rounded,
              accentColor: AppPalette.danger,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    await app.blockUserOrders(
                      userId: user.id,
                      reason: reasonController.text.trim(),
                      blockedDays: blockedDays == null || blockedDays == 0
                          ? null
                          : blockedDays,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Ограничить'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Причина ограничения',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: blockedDays,
                    decoration: const InputDecoration(
                      labelText: 'Срок блокировки',
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 день')),
                      DropdownMenuItem(value: 3, child: Text('3 дня')),
                      DropdownMenuItem(value: 7, child: Text('7 дней')),
                      DropdownMenuItem(value: 30, child: Text('30 дней')),
                      DropdownMenuItem(value: 0, child: Text('Бессрочно')),
                    ],
                    onChanged: (value) =>
                        setStateDialog(() => blockedDays = value),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    reasonController.dispose();
  }

  Future<void> _showUnblockUserDialog(
    BuildContext context,
    AppController app,
    AppUser user,
  ) async {
    final reasonController = TextEditingController(
      text: 'Проверено администратором, ограничение можно снять.',
    );

    await showAppDialog<void>(
      context: context,
      builder: (context) {
        return AppDialogShell(
          eyebrow: 'Risk control',
          title: 'Снять блокировку с ${user.fullName}?',
          subtitle:
              'Если у клиента всё ещё есть просроченный возврат, система автоматически вернёт autoblock после пересчёта риска.',
          icon: Icons.lock_open_rounded,
          accentColor: AppPalette.mint,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                await app.unblockUserOrders(
                  userId: user.id,
                  reason: reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Снять блок'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
            ],
          ),
        );
      },
    );

    reasonController.dispose();
  }

  Future<void> _showForceCompleteDialog(
    BuildContext context,
    AppController app,
    ActiveRentalSummary rental,
  ) async {
    final reasonController = TextEditingController(
      text: rental.isOverdue
          ? 'Принудительное закрытие просроченной аренды администратором.'
          : 'Закрыто администратором вручную.',
    );

    await showAppDialog<void>(
      context: context,
      builder: (context) {
        return AppDialogShell(
          eyebrow: 'Force complete',
          title: 'Закрыть аренду ${rental.orderCode}?',
          subtitle:
              'После этого заказ перейдёт в completed, возвратная тара вернётся на склад, а риск клиента будет пересчитан.',
          icon: Icons.assignment_turned_in_rounded,
          accentColor: rental.isOverdue ? AppPalette.danger : AppPalette.gold,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                await app.forceCompleteOrder(
                  orderId: rental.orderId,
                  reason: reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Закрыть аренду'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Причина force-close',
                ),
              ),
            ],
          ),
        );
      },
    );

    reasonController.dispose();
  }

  // ignore: unused_element
  Future<void> _editProduct(
    BuildContext context,
    AppController app,
    Product product,
  ) async {
    final priceController = TextEditingController(text: '${product.price}');
    final stockController = TextEditingController(text: '${product.stock}');

    await showAppDialog<void>(
      context: context,
      builder: (context) {
        return AppDialogShell(
          eyebrow: 'Catalog editor',
          title: product.title,
          subtitle:
              'Подправь цену и остаток, чтобы витрина и склад оставались синхронными.',
          icon: Icons.inventory_2_outlined,
          accentColor: AppPalette.rose,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                await app.updateProduct(
                  product.copyWith(
                    price: int.tryParse(priceController.text) ?? product.price,
                    stock: int.tryParse(stockController.text) ?? product.stock,
                  ),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Цена'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Остаток'),
              ),
            ],
          ),
        );
      },
    );

    priceController.dispose();
    stockController.dispose();
  }

  Future<void> _editProductSmart(
    BuildContext context,
    AppController app,
    Product product,
  ) async {
    final titleController = TextEditingController(text: product.title);
    final subtitleController = TextEditingController(text: product.subtitle);
    final priceController = TextEditingController(text: '${product.price}');
    final stockController = TextEditingController(text: '${product.stock}');
    final previewController = TextEditingController(
      text: product.previewImageUrl ?? '',
    );
    bool isVisible = product.isVisible;
    bool isFeatured = product.featured;

    await showAppDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AppDialogShell(
              eyebrow: 'Catalog editor',
              title: product.title,
              subtitle:
                  'Здесь можно отдельно управлять складом и витриной: скрывать товар от клиента, не обнуляя остаток.',
              icon: Icons.inventory_2_outlined,
              accentColor: AppPalette.rose,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    await app.updateProduct(
                      product.copyWith(
                        title: titleController.text.trim().isEmpty
                            ? product.title
                            : titleController.text.trim(),
                        subtitle: subtitleController.text.trim(),
                        price:
                            int.tryParse(priceController.text) ?? product.price,
                        stock:
                            int.tryParse(stockController.text) ?? product.stock,
                        featured: isFeatured,
                        isVisible: isVisible,
                        previewImageUrl: previewController.text.trim(),
                      ),
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: previewController,
                    decoration: const InputDecoration(labelText: 'URL превью'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Цена'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Остаток'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isVisible,
                    onChanged: (value) =>
                        setStateDialog(() => isVisible = value),
                    title: const Text('Показывать клиенту'),
                    subtitle: const Text(
                      'Если выключить, товар пропадёт из клиентского каталога, но останется в админке.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isFeatured,
                    onChanged: (value) =>
                        setStateDialog(() => isFeatured = value),
                    title: const Text('Показывать как хит каталога'),
                    subtitle: const Text(
                      'Товар будет поднят в блок рекомендованных позиций.',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    subtitleController.dispose();
    priceController.dispose();
    stockController.dispose();
    previewController.dispose();
  }
}

class _OrderFlowDetails extends StatelessWidget {
  const _OrderFlowDetails({
    super.key,
    required this.app,
    required this.order,
    required this.contract,
    required this.payment,
  });

  final AppController app;
  final OrderModel order;
  final ContractModel contract;
  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          'Заказ ${order.orderCode}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '${order.customerName} • ${order.location}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatusBadge(
              label: order.status.title,
              color: _statusColor(order.status),
            ),
            StatusBadge(
              label: 'Договор ${_humanizeFlowStatus(contract.status)}',
              color: contract.status == 'signed'
                  ? AppPalette.gold
                  : contract.status == 'rejected'
                  ? AppPalette.danger
                  : AppPalette.peach,
            ),
            StatusBadge(
              label: 'Платёж ${_humanizeFlowStatus(payment.status)}',
              color: payment.status == 'paid'
                  ? AppPalette.rose
                  : payment.status == 'failed'
                  ? AppPalette.danger
                  : AppPalette.peach,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FlowSection(
          title: 'Договор',
          subtitle: '${contract.documentNumber} • ${contract.signatureMethod}',
          children: [
            Text(
              contract.documentTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (contract.fileUrl?.isNotEmpty == true)
              Text(
                'Документ: ${contract.fileUrl}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showContractAccessSheet(
                    context: context,
                    app: app,
                    contract: contract,
                    orderCode: order.orderCode,
                    payment: payment,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Договор'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...contract.events.map(
              (event) => _FlowEventTile(
                icon: Icons.description_outlined,
                title: event.eventType,
                subtitle: _formatEventPayload(event.payload),
                trailing: _humanizeFlowStatus(event.status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FlowSection(
          title: 'Возвратная тара',
          subtitle:
              'Выдано ${order.issuedCylinderLogs.length} • Возвращено ${order.returnedCylinderLogs.length}',
          children: order.cylinderLogs.isEmpty
              ? [
                  Text(
                    'Для этого заказа возвратная тара не назначалась.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                    ),
                  ),
                ]
              : [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final log in order.cylinderLogs)
                        _CylinderLogAuditCard(log: log),
                    ],
                  ),
                ],
        ),
        const SizedBox(height: 16),
        _FlowSection(
          title: 'Платёж',
          subtitle: '${payment.provider} • ${payment.method}',
          children: [
            Text(
              'Сумма: ${rubles(payment.amount)} • ${payment.currency}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (payment.paymentMask?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Маска: ${payment.paymentMask}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
              ),
            ],
            if (payment.failureReason?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Причина: ${payment.failureReason}',
                style: const TextStyle(color: AppPalette.danger),
              ),
            ],
            const SizedBox(height: 12),
            ...payment.events.map(
              (event) => _FlowEventTile(
                icon: Icons.payments_outlined,
                title: event.eventType,
                subtitle: _formatEventPayload(event.payload),
                trailing: _humanizeFlowStatus(event.status),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RentalCodesPanel extends StatelessWidget {
  const _RentalCodesPanel({required this.title, required this.codes});

  final String title;
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in codes)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: AppPalette.mint.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CylinderLogAuditCard extends StatelessWidget {
  const _CylinderLogAuditCard({required this.log});

  final CylinderLogModel log;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.16),
        border: Border.all(
          color: _cylinderLogStatusColor(log.status).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(
            label: _humanizeCylinderStatus(log.status),
            color: _cylinderLogStatusColor(log.status),
          ),
          if ((log.qrCode ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'QR ${log.qrCode}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (log.serialNumber.isNotEmpty &&
              log.serialNumber != 'UNASSIGNED') ...[
            const SizedBox(height: 6),
            Text(
              'SN ${log.serialNumber}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
          ],
          if (log.issuedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Выдано: ${_formatDateTime(log.issuedAt)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
          ],
          if (log.returnedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Возврат: ${_formatDateTime(log.returnedAt)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.caption,
    required this.onTap,
    required this.actionLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String caption;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _AdminCollapsedPreviewPanel extends StatelessWidget {
  const _AdminCollapsedPreviewPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            SectionHeading(eyebrow: eyebrow, title: title, subtitle: subtitle),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.unfold_more_rounded),
                label: Text(actionLabel),
              ),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SectionHeading(
                    eyebrow: eyebrow,
                    title: title,
                    subtitle: subtitle,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.unfold_more_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CollapsedUserPreviewTile extends StatelessWidget {
  const _CollapsedUserPreviewTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return _CollapsedPreviewTileShell(
      title: user.fullName,
      subtitle:
          '@${user.login} • ${user.phone}${user.email.isNotEmpty ? ' • ${user.email}' : ''}',
      badges: [
        StatusBadge(
          label: user.isOrderBlocked ? 'Блок' : 'Ок',
          color: user.isOrderBlocked ? AppPalette.danger : AppPalette.mint,
        ),
        StatusBadge(
          label: 'Просрочек ${user.risk.overdueActiveOrders}',
          color: user.risk.overdueActiveOrders > 0
              ? AppPalette.peach
              : AppPalette.mint,
        ),
      ],
    );
  }
}

class _CollapsedRentalPreviewTile extends StatelessWidget {
  const _CollapsedRentalPreviewTile({required this.rental});

  final ActiveRentalSummary rental;

  @override
  Widget build(BuildContext context) {
    return _CollapsedPreviewTileShell(
      title: '${rental.orderCode} • ${rental.userFullName}',
      subtitle:
          '${rental.customerPhone} • ${rental.location} • ${rubles(rental.totalAmount)}',
      badges: [
        StatusBadge(
          label: 'В аренде ${rental.overdueDays} дн.',
          color: rental.isOverdue ? AppPalette.danger : AppPalette.peach,
        ),
        if (rental.cylinderSerials.isNotEmpty)
          StatusBadge(
            label: 'Серийников ${rental.cylinderSerials.length}',
            color: AppPalette.mint,
          ),
      ],
    );
  }
}

class _CollapsedEventPreviewTile extends StatelessWidget {
  const _CollapsedEventPreviewTile({required this.event});

  final AdminRiskEvent event;

  @override
  Widget build(BuildContext context) {
    return _CollapsedPreviewTileShell(
      title: _humanizeRiskEvent(event.eventType),
      subtitle:
          '${event.userFullName} • ${_formatDateTime(event.createdAt)}${event.orderCode?.isNotEmpty == true ? ' • ${event.orderCode}' : ''}',
      badges: [
        StatusBadge(
          label: _humanizeFlowStatus(event.status),
          color: event.status == 'blocked'
              ? AppPalette.danger
              : event.status == 'returned'
              ? AppPalette.mint
              : AppPalette.peach,
        ),
      ],
    );
  }
}

class _CollapsedOrderPreviewTile extends StatelessWidget {
  const _CollapsedOrderPreviewTile({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _CollapsedPreviewTileShell(
      title: '${order.orderCode} • ${order.customerName}',
      subtitle: '${order.customerPhone} • ${rubles(order.totalAmount)}',
      badges: [
        StatusBadge(
          label: order.status.title,
          color: _statusColor(order.status),
        ),
        StatusBadge(
          label: order.deliveryType == 'pickup' ? 'Самовывоз' : 'Доставка',
          color: AppPalette.mint,
        ),
      ],
    );
  }
}

class _CollapsedPreviewTileShell extends StatelessWidget {
  const _CollapsedPreviewTileShell({
    required this.title,
    required this.subtitle,
    required this.badges,
  });

  final String title;
  final String subtitle;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              height: 1.35,
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: badges),
          ],
        ],
      ),
    );
  }
}

class _AdminSectionToggleCard extends StatelessWidget {
  const _AdminSectionToggleCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final controls = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              if (trailing case final Widget trailingWidget) trailingWidget,
              if (trailing != null) const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(expanded ? 'Свернуть' : 'Развернуть'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  eyebrow: eyebrow,
                  title: title,
                  subtitle: subtitle,
                ),
                const SizedBox(height: 14),
                controls,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionHeading(
                  eyebrow: eyebrow,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              const SizedBox(width: 12),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order, required this.onOpen});

  final OrderModel order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.customerName} • ${order.orderCode}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.customerPhone} • ${order.location}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: order.status.title,
                      color: _statusColor(order.status),
                    ),
                    if (order.contractStatus != null)
                      StatusBadge(
                        label:
                            'Договор ${_humanizeFlowStatus(order.contractStatus!)}',
                        color: AppPalette.gold,
                      ),
                    if (order.paymentStatus != null)
                      StatusBadge(
                        label:
                            'Платёж ${_humanizeFlowStatus(order.paymentStatus!)}',
                        color: AppPalette.rose,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rubles(order.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppPalette.peach,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Открыть'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminProductCard extends StatelessWidget {
  const _AdminProductCard({required this.product, required this.onEdit});

  final Product product;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tint = parseHexColor(product.tint);
    return GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminProductPreview(product: product, tint: tint),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${rubles(product.price)} • остаток ${product.stock} ${product.unitLabel}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: product.requiresReturn
                          ? 'Возвратная тара'
                          : 'Расходник',
                      color: product.requiresReturn
                          ? AppPalette.gold
                          : AppPalette.rose,
                    ),
                    StatusBadge(
                      label: product.isVisible ? 'Виден клиенту' : 'Скрыт',
                      color: product.isVisible
                          ? AppPalette.mint
                          : AppPalette.plum,
                    ),
                    if (product.featured)
                      const StatusBadge(
                        label: 'Хит каталога',
                        color: AppPalette.peach,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Изменить'),
          ),
        ],
      ),
    );
  }
}

class _AdminProductPreview extends StatelessWidget {
  const _AdminProductPreview({required this.product, required this.tint});

  final Product product;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: product.previewImageUrl?.trim().isNotEmpty == true
            ? Image.network(
                product.previewImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AdminProductPreviewFallback(tint: tint, product: product),
              )
            : _AdminProductPreviewFallback(tint: tint, product: product),
      ),
    );
  }
}

class _AdminProductPreviewFallback extends StatelessWidget {
  const _AdminProductPreviewFallback({
    required this.tint,
    required this.product,
  });

  final Color tint;
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Icon(
            _adminCategoryIcon(product.category),
            color: tint,
            size: 28,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            color: Colors.black.withValues(alpha: 0.22),
            child: Text(
              'Превью',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminSearchPanel extends StatelessWidget {
  const _AdminSearchPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(eyebrow: eyebrow, title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FlowSection extends StatelessWidget {
  const _FlowSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FlowEventTile extends StatelessWidget {
  const _FlowEventTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppPalette.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: const TextStyle(
                color: AppPalette.peach,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isOverdueReturnOrder(OrderModel order) {
  if (order.status != OrderStatus.active || order.returnedAt != null) {
    return false;
  }
  if (!order.items.any((item) => item.requiresReturn) ||
      order.issuedAt == null) {
    return false;
  }

  return DateTime.now().difference(order.issuedAt!.toLocal()).inDays >= 3;
}

OrderModel? _findOrderById(List<OrderModel> orders, String orderId) {
  for (final order in orders) {
    if (order.id == orderId) {
      return order;
    }
  }
  return null;
}

bool _matchesAdminUser(
  AppUser user,
  String query, {
  required _AdminUserFilter filter,
}) {
  if (filter == _AdminUserFilter.blocked && !user.isOrderBlocked) {
    return false;
  }
  if (filter == _AdminUserFilter.overdue &&
      user.risk.overdueActiveOrders <= 0) {
    return false;
  }

  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  return _containsNormalized(user.fullName, normalized) ||
      _containsNormalized(user.login, normalized) ||
      _containsNormalized(user.phone, normalized) ||
      _containsNormalized(user.email, normalized) ||
      _containsNormalized(user.risk.blockReason, normalized) ||
      user.risk.overdueOrderCodes.any(
        (orderCode) => _containsNormalized(orderCode, normalized),
      );
}

bool _matchesActiveRental(
  ActiveRentalSummary rental,
  String query, {
  required _AdminRentalFilter filter,
}) {
  if (filter == _AdminRentalFilter.overdue && !rental.isOverdue) {
    return false;
  }
  if (filter == _AdminRentalFilter.withSerials &&
      rental.cylinderSerials.isEmpty) {
    return false;
  }

  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  return _containsNormalized(rental.orderCode, normalized) ||
      _containsNormalized(rental.userFullName, normalized) ||
      _containsNormalized(rental.userLogin, normalized) ||
      _containsNormalized(rental.customerPhone, normalized) ||
      _containsNormalized(rental.location, normalized) ||
      rental.cylinderSerials.any(
        (serial) => _containsNormalized(serial, normalized),
      );
}

bool _matchesAdminEvent(
  AdminRiskEvent event,
  String query, {
  required _AdminEventFilter filter,
}) {
  if (filter == _AdminEventFilter.blocking &&
      !(event.eventType.contains('block') || event.status == 'blocked')) {
    return false;
  }
  if (filter == _AdminEventFilter.returns &&
      !(event.eventType.contains('return') ||
          event.eventType.contains('complete') ||
          event.status == 'returned')) {
    return false;
  }
  if (filter == _AdminEventFilter.adminActions &&
      !event.eventType.startsWith('admin_')) {
    return false;
  }

  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  return _containsNormalized(_humanizeRiskEvent(event.eventType), normalized) ||
      _containsNormalized(event.userFullName, normalized) ||
      _containsNormalized(event.userLogin, normalized) ||
      _containsNormalized(event.orderCode, normalized) ||
      _containsNormalized(_formatEventPayload(event.payload), normalized);
}

bool _matchesAdminOrder(
  OrderModel order,
  String query, {
  required _AdminOrderFilter filter,
}) {
  if (filter == _AdminOrderFilter.awaitingSignature &&
      order.status != OrderStatus.awaitingSignature) {
    return false;
  }
  if (filter == _AdminOrderFilter.awaitingPayment &&
      order.status != OrderStatus.awaitingPayment) {
    return false;
  }
  if (filter == _AdminOrderFilter.paid && order.status != OrderStatus.paid) {
    return false;
  }
  if (filter == _AdminOrderFilter.active &&
      order.status != OrderStatus.active) {
    return false;
  }
  if (filter == _AdminOrderFilter.overdue && !_isOverdueReturnOrder(order)) {
    return false;
  }
  if (filter == _AdminOrderFilter.completed &&
      order.status != OrderStatus.completed) {
    return false;
  }

  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  return _containsNormalized(order.orderCode, normalized) ||
      _containsNormalized(order.customerName, normalized) ||
      _containsNormalized(order.customerPhone, normalized) ||
      _containsNormalized(order.location, normalized) ||
      _containsNormalized(order.paymentMask, normalized) ||
      order.issuedSerials.any(
        (serial) => _containsNormalized(serial, normalized),
      ) ||
      order.cylinderLogs.any(
        (log) => _containsNormalized(log.qrCode, normalized),
      );
}

IconData _adminCategoryIcon(String category) {
  switch (category) {
    case 'cylinder':
      return Icons.propane_tank_outlined;
    case 'kit':
      return Icons.celebration_outlined;
    case 'accessory':
      return Icons.build_circle_outlined;
    case 'safety':
      return Icons.health_and_safety_outlined;
    case 'decor':
      return Icons.auto_awesome_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

bool _containsNormalized(String? value, String normalizedQuery) {
  return (value ?? '').toLowerCase().contains(normalizedQuery);
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Без даты';
  }

  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} • $hour:$minute';
}

String _humanizeRiskEvent(String eventType) {
  switch (eventType) {
    case 'order_blocked':
      return 'Система заблокировала новые заказы';
    case 'order_unblocked':
      return 'Система сняла блокировку';
    case 'admin_manual_block':
      return 'Админ включил ручную блокировку';
    case 'admin_manual_unblock':
      return 'Админ снял ручную блокировку';
    case 'admin_force_complete':
      return 'Админ принудительно закрыл аренду';
    default:
      return eventType;
  }
}

Color _statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.draft:
      return AppPalette.plum;
    case OrderStatus.awaitingSignature:
      return AppPalette.gold;
    case OrderStatus.awaitingPayment:
      return AppPalette.peach;
    case OrderStatus.paid:
      return AppPalette.rose;
    case OrderStatus.active:
      return AppPalette.gold;
    case OrderStatus.completed:
      return AppPalette.mint;
    case OrderStatus.blocked:
      return AppPalette.danger;
  }
}

String _humanizeFlowStatus(String value) {
  switch (value) {
    case 'pending_signature':
      return 'ждёт подписи';
    case 'signed':
      return 'подписан';
    case 'rejected':
      return 'отклонён';
    case 'pending':
      return 'ждёт оплаты';
    case 'paid':
      return 'оплачен';
    case 'failed':
      return 'ошибка';
    case 'blocked':
      return 'заблокирован';
    case 'clear':
      return 'очищен';
    case 'returned':
      return 'возврат';
    case 'created':
      return 'создан';
    case 'generated':
      return 'создан';
    case 'signature_requested':
      return 'запрошен';
    default:
      return value;
  }
}

Color _cylinderLogStatusColor(String value) {
  switch (value) {
    case 'returned':
      return AppPalette.mint;
    case 'issued':
      return AppPalette.gold;
    default:
      return AppPalette.peach;
  }
}

String _humanizeCylinderStatus(String value) {
  switch (value) {
    case 'returned':
      return 'Возвращено';
    case 'issued':
      return 'Выдано';
    case 'reserved':
      return 'Зарезервировано';
    default:
      return value;
  }
}

String _formatEventPayload(Map<String, dynamic>? payload) {
  if (payload == null || payload.isEmpty) {
    return 'Без дополнительных данных';
  }

  return payload.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join(' • ');
}
