import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/contract_access_sheet.dart';
import '../widgets/neon_ui.dart';

class OrderPassScreen extends StatelessWidget {
  const OrderPassScreen({super.key, required this.order});

  final OrderModel order;

  String get _qrData => 'INDGAS_ORDER:${order.orderCode}';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);

    return Scaffold(
      appBar: AppBar(title: const Text('QR-пропуск заказа')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(
                  eyebrow: 'Order pass',
                  title: 'Покажи этот QR курьеру',
                  subtitle:
                      'Курьер может считать код камерой или ввести код заказа вручную, если сканер временно недоступен.',
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: SelectableText(
                    order.orderCode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.8,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    MetricChip(
                      label: 'Статус заказа',
                      value: order.status.title,
                      color: AppPalette.rose,
                    ),
                    if (order.contractStatus != null)
                      MetricChip(
                        label: 'Договор',
                        value: _humanizeFlowStatus(order.contractStatus!),
                        color: AppPalette.gold,
                      ),
                    if (order.paymentStatus != null)
                      MetricChip(
                        label: 'Платёж',
                        value: _humanizeFlowStatus(order.paymentStatus!),
                        color: AppPalette.peach,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: AppPalette.gold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.location,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Сумма: ${rubles(order.totalAmount)} • ${order.itemCount} поз.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Резервный код для ручного ввода: ${order.orderCode}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                      if (order.issuedSerials.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Выданные серийники: ${order.issuedSerials.join(', ')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyOrderCode(context),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Копировать код'),
                    ),
                    if (order.contractId?.isNotEmpty == true)
                      OutlinedButton.icon(
                        onPressed: () => _openContract(context, app),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Договор'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyOrderCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: order.orderCode));
    if (!context.mounted) return;
    showInfoSnackBar(context, 'Код заказа скопирован.');
  }

  Future<void> _openContract(BuildContext context, AppController app) async {
    try {
      final contract = await app.getOrderContract(order.id);
      if (!context.mounted) return;
      await showContractAccessSheet(
        context: context,
        app: app,
        contract: contract,
        orderCode: order.orderCode,
      );
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Не удалось открыть договор. Попробуйте ещё раз.',
      );
    }
  }
}

String _humanizeFlowStatus(String value) {
  switch (value) {
    case 'pending_signature':
      return 'Ждёт подписи';
    case 'signed':
      return 'Подписан';
    case 'rejected':
      return 'Отклонён';
    case 'pending':
      return 'Ждёт оплаты';
    case 'paid':
      return 'Оплачен';
    case 'failed':
      return 'Ошибка';
    default:
      return value;
  }
}
