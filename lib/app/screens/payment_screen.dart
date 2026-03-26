import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/contract_access_sheet.dart';
import '../widgets/neon_ui.dart';
import 'order_pass_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _holderController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _cvvController = TextEditingController();

  String _deliveryType = 'pickup';

  @override
  void dispose() {
    _locationController.dispose();
    _cardNumberController.dispose();
    _holderController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String get _maskedCard {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : '0000';
    return '•••• $last4';
  }

  String get _formattedCardPreview {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final padded = digits.padRight(16, '•');
    final groups = <String>[];
    for (var i = 0; i < 16; i += 4) {
      groups.add(padded.substring(i, i + 4));
    }
    return groups.join(' ');
  }

  String get _cardBrand {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('220')) return 'MIR';
    if (digits.startsWith('4')) return 'VISA';
    if (digits.startsWith('5') || digits.startsWith('2')) return 'MC';
    return 'GAS PAY';
  }

  String get _deliveryLabel =>
      _deliveryType == 'pickup' ? 'Самовывоз' : 'Доставка';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final app = AppScope.read(context);
    try {
      final order = await app.submitOrder(
        deliveryType: _deliveryType,
        location: _locationController.text.trim(),
        paymentMethod: 'card_demo',
        paymentMask: _maskedCard,
      );
      ContractModel? contract;
      try {
        contract = await app.getOrderContract(order.id);
      } catch (_) {
        contract = null;
      }
      if (!mounted) return;
      await showAppDialog<void>(
        context: context,
        builder: (context) {
          return AppDialogShell(
            eyebrow: 'Success state',
            title: 'Оплата подтверждена',
            subtitle:
                'Заказ уже сохранён, история обновлена, а документ можно открыть сразу после этого окна.',
            icon: Icons.check_circle_outline_rounded,
            accentColor: AppPalette.mint,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Продолжить'),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricChip(
                  label: 'Код заказа',
                  value: order.orderCode,
                  color: AppPalette.mint,
                ),
                const SizedBox(height: 14),
                Text(
                  'В demo-flow договор подписан stub-механикой, затем платёж подтверждён, а backend по-прежнему хранит только маску карты.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (!mounted) return;
      if (contract != null) {
        await showContractAccessSheet(
          context: context,
          app: app,
          contract: contract,
          orderCode: order.orderCode,
        );
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderPassScreen(order: order)),
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback:
            'Не удалось завершить оформление. Проверьте данные и попробуйте снова.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final user = app.currentUser;
    final risk = user?.risk;
    final isOrderBlocked = user?.isOrderBlocked ?? false;

    if (app.cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оформление и оплата')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Checkout',
                    title: 'Сначала соберите заказ',
                    subtitle:
                        'Сейчас корзина пустая, поэтому оформлять пока нечего. Добавьте позиции из каталога или соберите набор через помощник.',
                  ),
                  const SizedBox(height: 16),
                  const EmptyStatePanel(
                    title: 'Корзина пустая',
                    message:
                        'Когда товары появятся в корзине, здесь откроется доставка, карта оплаты и договорный flow.',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Вернуться назад'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление и оплата')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RevealOnMount(
            child: GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Checkout',
                    title: 'Мягкий, тёплый и уверенный сценарий оплаты',
                    subtitle:
                        'Checkout проходит как настоящий flow: сначала stub-подписание договора, потом stub-подтверждение оплаты, а backend получает только безопасную маску карты.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      MetricChip(
                        label: 'К оплате',
                        value: rubles(app.cartTotal),
                        color: AppPalette.rose,
                      ),
                      MetricChip(
                        label: 'Получение',
                        value: _deliveryLabel,
                        color: AppPalette.gold,
                      ),
                      MetricChip(
                        label: 'Бренд карты',
                        value: _cardBrand,
                        color: AppPalette.peach,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AnimatedContainer(
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 250),
                      reduced: Duration.zero,
                    ),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppPalette.panelStrong,
                          AppPalette.rose.withValues(alpha: 0.30),
                          AppPalette.peach.withValues(alpha: 0.24),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.rose.withValues(alpha: 0.22),
                          blurRadius: 34,
                          offset: const Offset(0, 22),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD87A),
                                    Color(0xFFC99112),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              child: Text(
                                _cardBrand,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Celebrate safely',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.66),
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formattedCardPreview,
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: _CardMeta(
                                label: 'CARD HOLDER',
                                value: _holderController.text.isEmpty
                                    ? 'YOUR NAME'
                                    : _holderController.text.toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CardMeta(
                                label: 'EXPIRES',
                                value:
                                    '${_monthController.text.padRight(2, 'M')}/${_yearController.text.padRight(2, 'Y')}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOrderBlocked) ...[
            const SizedBox(height: 16),
            RevealOnMount(
              delay: const Duration(milliseconds: 70),
              child: GlassPanel(
                borderColor: AppPalette.danger.withValues(alpha: 0.18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      eyebrow: 'Risk control',
                      title: 'Оформление временно заблокировано',
                      subtitle:
                          'Backend уже проверяет просроченные активные аренды и не даст создать новый заказ до закрытия возврата.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: AppPalette.danger.withValues(alpha: 0.10),
                        border: Border.all(
                          color: AppPalette.danger.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            risk?.blockReason ??
                                'Сначала закрой активную аренду с возвратной тарой.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          if (risk?.overdueOrderCodes.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Проблемные заказы: ${risk!.overdueOrderCodes.join(', ')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (app.cart.isNotEmpty) ...[
            const SizedBox(height: 16),
            RevealOnMount(
              delay: const Duration(milliseconds: 90),
              child: GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      eyebrow: 'Order lines',
                      title: 'Состав заказа перед оплатой',
                      subtitle:
                          'Возвратная тара и продажные позиции показаны отдельно, чтобы перед оплатой не оставалось вопросов.',
                    ),
                    const SizedBox(height: 16),
                    ...app.cart.asMap().entries.map(
                      (entry) => RevealOnMount(
                        delay: Duration(milliseconds: 120 + (entry.key * 40)),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CheckoutItemLine(entry: entry.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          RevealOnMount(
            delay: const Duration(milliseconds: 180),
            child: GlassPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppPalette.gold.withValues(alpha: 0.12),
                            AppPalette.rose.withValues(alpha: 0.10),
                          ],
                        ),
                        border: Border.all(
                          color: AppPalette.gold.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                            child: const Icon(Icons.lock_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Подписание и платёж',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Сначала backend проводит stub-подпись договора, затем подтверждает оплату. Номер карты форматируется на клиенте, CVV не попадает в API.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.70),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'pickup',
                          label: Text('Самовывоз'),
                        ),
                        ButtonSegment(
                          value: 'delivery',
                          label: Text('Доставка'),
                        ),
                      ],
                      selected: {_deliveryType},
                      onSelectionChanged: (value) {
                        setState(() => _deliveryType = value.first);
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: _deliveryType == 'pickup'
                            ? 'Точка выдачи'
                            : 'Адрес доставки',
                        helperText: _deliveryType == 'pickup'
                            ? 'Например: склад, пункт выдачи или согласованная точка самовывоза.'
                            : 'Укажите адрес так, чтобы курьеру не пришлось уточнять детали по звонку.',
                        prefixIcon: const Icon(Icons.place_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Укажите место получения';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CardNumberFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Номер карты',
                        hintText: '0000 0000 0000 0000',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final digits =
                            value?.replaceAll(RegExp(r'\D'), '') ?? '';
                        if (digits.length < 16) {
                          return 'Введите 16 цифр карты';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _holderController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Имя держателя',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().length < 4) {
                          return 'Введите имя держателя';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _monthController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(labelText: 'MM'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final month = int.tryParse(value ?? '');
                              if (month == null || month < 1 || month > 12) {
                                return 'MM';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(labelText: 'YY'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if ((value ?? '').length != 2) {
                                return 'YY';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'CVV'),
                            validator: (value) {
                              if ((value ?? '').length < 3) {
                                return 'CVV';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isOrderBlocked
                            ? AppPalette.danger.withValues(alpha: 0.08)
                            : AppPalette.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isOrderBlocked
                              ? AppPalette.danger.withValues(alpha: 0.18)
                              : AppPalette.gold.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOrderBlocked
                                ? Icons.gpp_bad_outlined
                                : Icons.shield_outlined,
                            color: isOrderBlocked
                                ? AppPalette.danger
                                : AppPalette.gold,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isOrderBlocked
                                  ? (risk?.blockReason ??
                                        'Backend временно не разрешает новые заказы, пока не закрыта просроченная аренда.')
                                  : 'К оплате ${rubles(app.cartTotal)}. Demo backend сначала помечает договор как signed, затем переводит платёж в paid и хранит только маску $_maskedCard.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [AppPalette.rose, AppPalette.peach],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.rose.withValues(alpha: 0.24),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: app.isBusy || isOrderBlocked
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            app.isBusy
                                ? 'Подписываем и оплачиваем...'
                                : isOrderBlocked
                                ? 'Оформление недоступно'
                                : 'Оплатить ${rubles(app.cartTotal)}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutItemLine extends StatelessWidget {
  const _CheckoutItemLine({required this.entry});

  final CartEntry entry;

  @override
  Widget build(BuildContext context) {
    final tint = parseHexColor(entry.product.tint);

    return RepaintBoundary(
      child: HoverLift(
        hoverOffset: 5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: tint.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: tint.withValues(alpha: 0.14),
                ),
                child: Icon(
                  entry.product.requiresReturn
                      ? Icons.local_shipping_outlined
                      : Icons.inventory_2_outlined,
                  color: tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.product.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.quantity} ${entry.product.unitLabel} • ${entry.product.requiresReturn ? 'возвратная тара' : 'продажа'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                rubles(entry.subtotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
