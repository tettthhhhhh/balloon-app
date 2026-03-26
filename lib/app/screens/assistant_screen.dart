import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/neon_ui.dart';
import 'video_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _balloonsController = TextEditingController(text: '30');
  final _hoursController = TextEditingController(text: '4');

  @override
  void dispose() {
    _balloonsController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  int get balloonsCount => int.tryParse(_balloonsController.text) ?? 0;
  int get eventHours => int.tryParse(_hoursController.text) ?? 0;

  int get recommendedGasUnits {
    final balloons = balloonsCount.clamp(0, 10000);
    final hours = eventHours.clamp(1, 24);
    final baseUnits = (balloons / 35).ceil();
    final reserve = hours > 6 ? 1 : 0;
    return math.max(1, baseUnits + reserve);
  }

  int get recommendedLatexPacks {
    if (balloonsCount <= 0) return 0;
    return math.max(1, (balloonsCount / 100).ceil());
  }

  int get recommendedStandUnits => balloonsCount >= 70 ? 1 : 0;

  int get eventReserveMinutes => (eventHours * 12).clamp(12, 240);

  void _applyPreset({required int balloons, required int hours}) {
    setState(() {
      _balloonsController.text = '$balloons';
      _hoursController.text = '$hours';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final gasProduct = app.products.firstWhere(
      (product) => product.requiresReturn,
      orElse: () => const Product(
        id: '',
        title: 'Гелиевый комплект',
        subtitle: '',
        category: 'gas',
        price: 0,
        stock: 0,
        unitLabel: 'шт',
        requiresReturn: true,
        featured: false,
        isVisible: true,
        tint: '#FF7AA8',
      ),
    );
    final latexProduct = app.products.firstWhere(
      (product) => !product.requiresReturn && product.category == 'consumable',
      orElse: () => const Product(
        id: '',
        title: 'Набор шаров',
        subtitle: '',
        category: 'consumable',
        price: 0,
        stock: 0,
        unitLabel: 'уп',
        requiresReturn: false,
        featured: false,
        isVisible: true,
        tint: '#FFD36F',
      ),
    );
    final standProduct = app.products.firstWhere(
      (product) => product.id == 'arch-stand-mini',
      orElse: () => const Product(
        id: '',
        title: 'Стойка для фотозоны',
        subtitle: '',
        category: 'equipment',
        price: 0,
        stock: 0,
        unitLabel: 'шт',
        requiresReturn: true,
        featured: false,
        isVisible: true,
        tint: '#FFB26B',
      ),
    );
    final recommendationTotal =
        (gasProduct.price * recommendedGasUnits) +
        (latexProduct.price * recommendedLatexPacks) +
        (standProduct.price * recommendedStandUnits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Помощник по заказу'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoScreen(
                    videoId: app.config.safetyVideoId,
                    title: 'Инструкция по технике безопасности',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RevealOnMount(
            child: GlassPanel(
              padding: const EdgeInsets.all(0),
              borderColor: AppPalette.gold.withValues(alpha: 0.16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.gold.withValues(alpha: 0.14),
                      AppPalette.rose.withValues(alpha: 0.10),
                      AppPalette.panelStrong.withValues(alpha: 0.96),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      eyebrow: 'Smart helper',
                      title: 'Подскажу, сколько взять гелия и шаров',
                      subtitle:
                          'Помощник считает аренду и продажу вместе, чтобы заказ выглядел целостно и без нехватки на площадке.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        MetricChip(
                          label: 'Рекомендуем баллонов',
                          value: '$recommendedGasUnits шт',
                          color: AppPalette.rose,
                        ),
                        MetricChip(
                          label: 'Пачек шаров',
                          value: '$recommendedLatexPacks уп',
                          color: AppPalette.gold,
                        ),
                        MetricChip(
                          label: 'Резерв по времени',
                          value: '$eventReserveMinutes мин',
                          color: AppPalette.mint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: Colors.black.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppPalette.peach.withValues(alpha: 0.14),
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: AppPalette.peach,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Если расчёт нестандартный, менеджер быстро поможет: ${app.config.supportPhone}.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          RevealOnMount(
            delay: const Duration(milliseconds: 90),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Event setup',
                    title: 'Соберём рекомендацию под событие',
                    subtitle:
                        'Выбери один из типовых сценариев или введи свои значения вручную.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _PresetChip(
                        label: 'День рождения',
                        detail: '30 шаров • 4 часа',
                        onTap: () => _applyPreset(balloons: 30, hours: 4),
                      ),
                      _PresetChip(
                        label: 'Свадьба',
                        detail: '80 шаров • 8 часов',
                        onTap: () => _applyPreset(balloons: 80, hours: 8),
                      ),
                      _PresetChip(
                        label: 'Фотозона',
                        detail: '120 шаров • 10 часов',
                        onTap: () => _applyPreset(balloons: 120, hours: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _balloonsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Количество шаров',
                      prefixIcon: Icon(Icons.celebration_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Длительность мероприятия (часы)',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          RevealOnMount(
            delay: const Duration(milliseconds: 170),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Recommendation',
                    title: 'Что стоит добавить в заказ',
                    subtitle:
                        'Собрали одну рекомендацию из аренды и продажи, чтобы не пришлось считать это вручную.',
                  ),
                  const SizedBox(height: 16),
                  _RecommendationLine(
                    icon: Icons.local_shipping_outlined,
                    title: gasProduct.title,
                    subtitle: 'Возвратная тара • $recommendedGasUnits шт',
                    total: rubles(gasProduct.price * recommendedGasUnits),
                    color: AppPalette.rose,
                  ),
                  if (recommendedStandUnits > 0 &&
                      standProduct.id.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _RecommendationLine(
                      icon: Icons.view_in_ar_outlined,
                      title: standProduct.title,
                      subtitle:
                          'Опора для оформления • $recommendedStandUnits шт',
                      total: rubles(standProduct.price * recommendedStandUnits),
                      color: AppPalette.peach,
                    ),
                  ],
                  if (recommendedLatexPacks > 0) ...[
                    const SizedBox(height: 12),
                    _RecommendationLine(
                      icon: Icons.inventory_2_outlined,
                      title: latexProduct.title,
                      subtitle: 'Продажный товар • $recommendedLatexPacks уп',
                      total: rubles(latexProduct.price * recommendedLatexPacks),
                      color: AppPalette.gold,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: AppPalette.peach.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ориентировочная сумма набора',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.64),
                            ),
                          ),
                        ),
                        Text(
                          rubles(recommendationTotal),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VideoScreen(
                                  videoId: app.config.safetyVideoId,
                                  title: 'Как работать с гелием безопасно',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Смотреть инструкцию'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [AppPalette.rose, AppPalette.peach],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.rose.withValues(alpha: 0.24),
                                blurRadius: 22,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: gasProduct.id.isEmpty
                                ? null
                                : () {
                                    app.addToCart(
                                      gasProduct,
                                      quantity: recommendedGasUnits,
                                    );
                                    if (latexProduct.id.isNotEmpty) {
                                      app.addToCart(
                                        latexProduct,
                                        quantity: recommendedLatexPacks,
                                      );
                                    }
                                    if (standProduct.id.isNotEmpty) {
                                      app.addToCart(
                                        standProduct,
                                        quantity: recommendedStandUnits,
                                      );
                                    }
                                    showInfoSnackBar(
                                      context,
                                      'Рекомендация добавлена: $recommendedGasUnits баллонов, $recommendedLatexPacks упаковок шаров и $recommendedStandUnits стоек.',
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Добавить рекомендацию'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      scale: 1.02,
      hoverOffset: 5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppPalette.gold.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                detail,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationLine extends StatelessWidget {
  const _RecommendationLine({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      hoverOffset: 5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              total,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
