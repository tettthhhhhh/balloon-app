import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_ui.dart';

class CourierScreen extends StatelessWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Панель курьера'),
          actions: [
            IconButton(
              onPressed: app.refreshOrders,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: app.logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'К выдаче'),
              Tab(text: 'Активные'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CourierOrdersList(
              title: 'Оплаченные заказы',
              subtitle:
                  'Берём заказ в работу, указываем серийный номер баллона и переводим его в активные.',
              orders: app.paidOrders,
              onAction: (order) async {
                final serial = await _askSerial(context);
                if (serial == null || serial.trim().isEmpty) return;
                await app.issueOrder(
                  orderId: order.id,
                  cylinderSerial: serial.trim(),
                );
              },
              actionLabel: 'Выдать',
              actionColor: AppPalette.cyan,
            ),
            _CourierOrdersList(
              title: 'Активные заказы',
              subtitle:
                  'Когда баллон вернулся, завершаем заказ и автоматически возвращаем складской остаток.',
              orders: app.activeOrders,
              onAction: (order) => app.completeOrder(order.id),
              actionLabel: 'Завершить',
              actionColor: AppPalette.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierOrdersList extends StatelessWidget {
  const _CourierOrdersList({
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.onAction,
    required this.actionLabel,
    required this.actionColor,
  });

  final String title;
  final String subtitle;
  final List<OrderModel> orders;
  final Future<void> Function(OrderModel order) onAction;
  final String actionLabel;
  final Color actionColor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassPanel(
          child: SectionHeading(
            eyebrow: 'Courier flow',
            title: title,
            subtitle: subtitle,
          ),
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          const EmptyStatePanel(
            title: 'Список пуст',
            message:
                'Когда появятся заказы в этой стадии, здесь будут коды, состав и быстрые действия.',
            icon: Icons.inventory_2_outlined,
          )
        else
          ...orders.map(
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
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: order.status.title,
                          color: actionColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${order.location} • ${order.customerPhone}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      order.items
                          .map((item) => '${item.title} x${item.quantity}')
                          .join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (order.cylinderSerial?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Серийный номер: ${order.cylinderSerial}',
                        style: const TextStyle(color: AppPalette.cyan),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => onAction(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                        ),
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<String?> _askSerial(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Серийный номер баллона'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Например GX-2026-0017'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
