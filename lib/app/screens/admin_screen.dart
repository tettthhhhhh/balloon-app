import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_ui.dart';

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

  @override
  void initState() {
    super.initState();
    _promoController = TextEditingController();
    _safetyController = TextEditingController();
    _supportController = TextEditingController();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _promoController.dispose();
    _safetyController.dispose();
    _supportController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    _promoController.text = app.config.promoVideoId;
    _safetyController.text = app.config.safetyVideoId;
    _supportController.text = app.config.supportPhone;
    _messageController.text = app.config.brandMessage;

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
                  title: 'Статусы, склад, конфиг и витрина',
                  subtitle:
                      'Вся логика уже привязана к backend: метрики считаются по заказам, а остатки идут по продуктам.',
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
                        color: AppPalette.cyan,
                      ),
                    ),
                    SizedBox(
                      width: 146,
                      child: MetricChip(
                        label: 'Активные',
                        value: '${app.dashboard.activeOrders}',
                        color: AppPalette.orange,
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Future<void> _editProduct(
    BuildContext context,
    AppController app,
    Product product,
  ) async {
    final priceController = TextEditingController(text: '${product.price}');
    final stockController = TextEditingController(text: '${product.stock}');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product.title),
          content: Column(
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
        );
      },
    );

    priceController.dispose();
    stockController.dispose();
  }
}
