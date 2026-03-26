import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/contract_access_sheet.dart';
import '../widgets/neon_ui.dart';
import 'assistant_screen.dart';
import 'order_pass_screen.dart';
import 'payment_screen.dart';
import 'video_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _CatalogTab(onOpenAssistant: () => setState(() => _index = 1)),
      const AssistantScreen(),
      _CartTab(
        onBrowseCatalog: () => setState(() => _index = 0),
        onOpenAssistant: () => setState(() => _index = 1),
      ),
      _ProfileTab(
        onBrowseCatalog: () => setState(() => _index = 0),
        onOpenAssistant: () => setState(() => _index = 1),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: AppPalette.panelStrong.withValues(alpha: 0.92),
            border: Border.all(color: AppPalette.gold.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: NavigationBar(
            height: 74,
            selectedIndex: _index,
            backgroundColor: Colors.transparent,
            indicatorColor: AppPalette.rose.withValues(alpha: 0.16),
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Каталог',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Помощник',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag_rounded),
                label: 'Корзина',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CatalogKindFilter { all, returnable, sale }

class _CatalogTab extends StatefulWidget {
  const _CatalogTab({required this.onOpenAssistant});

  final VoidCallback onOpenAssistant;

  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> {
  _CatalogKindFilter _kindFilter = _CatalogKindFilter.all;
  String? _categoryFilter;

  List<Product> _applyFilters(List<Product> products) => products
      .where((product) {
        final matchesKind = switch (_kindFilter) {
          _CatalogKindFilter.all => true,
          _CatalogKindFilter.returnable => product.requiresReturn,
          _CatalogKindFilter.sale => !product.requiresReturn,
        };
        final matchesCategory =
            _categoryFilter == null || product.category == _categoryFilter;
        return matchesKind && matchesCategory;
      })
      .toList(growable: false);

  void _toggleCategory(String category) {
    setState(() {
      _categoryFilter = _categoryFilter == category ? null : category;
    });
  }

  void _setKind(_CatalogKindFilter value) {
    setState(() {
      _kindFilter = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final featuredBase = app.featuredProducts.isEmpty
        ? app.products
        : app.featuredProducts;
    final featured = _applyFilters(featuredBase);
    final filteredProducts = _applyFilters(app.products);
    final categories =
        app.products.map((product) => product.category).toSet().toList()..sort(
          (left, right) =>
              _categoryLabel(left).compareTo(_categoryLabel(right)),
        );

    return RefreshIndicator(
      onRefresh: app.refreshPublicData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: useCompactLayout(context) ? 640 : 1200,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: RevealOnMount(
                child: _CatalogHero(
                  app: app,
                  onOpenAssistant: widget.onOpenAssistant,
                ),
              ),
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: RevealOnMount(
                  delay: const Duration(milliseconds: 80),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Все'),
                        selected: _kindFilter == _CatalogKindFilter.all,
                        onSelected: (_) => _setKind(_CatalogKindFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('Возвратная тара'),
                        selected: _kindFilter == _CatalogKindFilter.returnable,
                        onSelected: (_) =>
                            _setKind(_CatalogKindFilter.returnable),
                      ),
                      ChoiceChip(
                        label: const Text('Продажа'),
                        selected: _kindFilter == _CatalogKindFilter.sale,
                        onSelected: (_) => _setKind(_CatalogKindFilter.sale),
                      ),
                      for (final category in categories)
                        _CatalogFilterChip(
                          icon: _categoryIcon(category),
                          label: _categoryLabel(category),
                          selected: _categoryFilter == category,
                          onTap: () => _toggleCategory(category),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          if (featured.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: SectionHeading(
                  eyebrow: 'Featured',
                  title: 'Рекомендуемые позиции',
                  subtitle:
                      'То, что чаще всего берут для быстрых заказов, праздников и декора.',
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = featured[index];
                  return RevealOnMount(
                    delay: Duration(milliseconds: 100 + (index * 70)),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: index == featured.length - 1 ? 8 : 12,
                      ),
                      child: _InteractiveProductCard(
                        product: product,
                        highlight: true,
                        onKindTap: () => _setKind(
                          product.requiresReturn
                              ? _CatalogKindFilter.returnable
                              : _CatalogKindFilter.sale,
                        ),
                        onCategoryTap: () => _toggleCategory(product.category),
                      ),
                    ),
                  );
                }, childCount: featured.length),
              ),
            ),
          ],
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeading(
                eyebrow: 'All products',
                title: 'Весь каталог',
                subtitle:
                    'Возвратная тара и продажные товары теперь визуально различаются с первого взгляда.',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (app.products.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: EmptyStatePanel(
                  title: 'Каталог пуст',
                  message:
                      'Сервер ещё не отдал данные по товарам. Проверь backend и обнови экран.',
                ),
              ),
            )
          else if (filteredProducts.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: EmptyStatePanel(
                  title: 'По фильтрам ничего не найдено',
                  message:
                      'Сними часть фильтров или переключись между возвратной тарой и продажными товарами.',
                  icon: Icons.filter_alt_off_rounded,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = filteredProducts[index];
                  return RevealOnMount(
                    delay: Duration(milliseconds: 140 + (index * 45)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InteractiveProductCard(
                        product: product,
                        onKindTap: () => _setKind(
                          product.requiresReturn
                              ? _CatalogKindFilter.returnable
                              : _CatalogKindFilter.sale,
                        ),
                        onCategoryTap: () => _toggleCategory(product.category),
                      ),
                    ),
                  );
                }, childCount: filteredProducts.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatalogHero extends StatelessWidget {
  const _CatalogHero({required this.app, required this.onOpenAssistant});

  final AppController app;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) {
    final saleCount = app.products
        .where((product) => !product.requiresReturn)
        .length;
    final returnCount = app.products
        .where((product) => product.requiresReturn)
        .length;

    return GlassPanel(
      padding: const EdgeInsets.all(0),
      borderColor: AppPalette.peach.withValues(alpha: 0.18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.rose.withValues(alpha: 0.18),
              AppPalette.panelStrong.withValues(alpha: 0.96),
              AppPalette.peach.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -28,
              left: -18,
              child: _DecorBubble(size: 120, color: AppPalette.rose),
            ),
            const Positioned(
              right: -10,
              top: 24,
              child: _DecorBubble(size: 112, color: AppPalette.peach),
            ),
            const Positioned(
              right: 36,
              bottom: -36,
              child: _DecorBubble(size: 150, color: AppPalette.gold),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: AppPalette.gold.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Balloons and Helium',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                  color: AppPalette.gold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Шары, гелий\nи продажа без путаницы',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              app.config.brandMessage,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.74),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppPalette.rose, AppPalette.peach],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.rose.withValues(alpha: 0.28),
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.celebration_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      MetricChip(
                        label: 'Возвратные позиции',
                        value: '$returnCount шт',
                        color: AppPalette.rose,
                      ),
                      MetricChip(
                        label: 'Продажные товары',
                        value: '$saleCount шт',
                        color: AppPalette.gold,
                      ),
                      MetricChip(
                        label: 'Хиты каталога',
                        value: '${app.featuredProducts.length}',
                        color: AppPalette.mint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black.withValues(alpha: 0.18),
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
                            color: AppPalette.gold.withValues(alpha: 0.14),
                          ),
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            color: AppPalette.gold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Аренда и продажа уже разделены в карточках, поэтому клиент сразу понимает, что нужно вернуть, а что остаётся у него.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      DecoratedBox(
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
                          onPressed: onOpenAssistant,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Подобрать заказ'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VideoScreen(
                                videoId: app.config.promoVideoId,
                                title: 'Как оформить заказ',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Смотреть обзор'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogFilterChip extends StatelessWidget {
  const _CatalogFilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      scale: 1.02,
      hoverOffset: 5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? AppPalette.rose.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: selected
                    ? AppPalette.rose.withValues(alpha: 0.24)
                    : AppPalette.peach.withValues(alpha: 0.16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppPalette.rose : AppPalette.gold,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppPalette.rose : AppPalette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductMetaChip extends StatelessWidget {
  const _ProductMetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return HoverLift(
      scale: 1.01,
      hoverOffset: 4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withValues(alpha: enabled ? 0.12 : 0.08),
              border: Border.all(
                color: color.withValues(alpha: enabled ? 0.24 : 0.14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled ? AppPalette.text : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorBubble extends StatelessWidget {
  const _DecorBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.42),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveProductCard extends StatelessWidget {
  const _InteractiveProductCard({
    required this.product,
    this.highlight = false,
    this.onKindTap,
    this.onCategoryTap,
  });

  final Product product;
  final bool highlight;
  final VoidCallback? onKindTap;
  final VoidCallback? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final tint = parseHexColor(product.tint);
    final inCartCount = app.cart
        .where((entry) => entry.product.id == product.id)
        .fold(0, (sum, entry) => sum + entry.quantity);
    final stockDenominator = (product.stock + 4).clamp(1, 24);
    final stockRatio = (product.stock / stockDenominator).clamp(0.0, 1.0);
    final hasPreview = product.previewImageUrl?.trim().isNotEmpty == true;

    return RepaintBoundary(
      child: HoverLift(
        child: GlassPanel(
          borderColor: tint.withValues(alpha: highlight ? 0.30 : 0.18),
          padding: const EdgeInsets.all(0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: highlight
                    ? [
                        tint.withValues(alpha: 0.14),
                        AppPalette.panel.withValues(alpha: 0.92),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductPreview(product: product, tint: tint),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.66),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: tint.withValues(alpha: 0.14),
                      ),
                      child: Text(
                        rubles(product.price),
                        style: TextStyle(
                          color: tint,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ProductMetaChip(
                      label: product.requiresReturn
                          ? 'Возвратная тара'
                          : 'Продажа',
                      onTap: onKindTap,
                      icon: product.requiresReturn
                          ? Icons.assignment_return_rounded
                          : Icons.shopping_bag_rounded,
                      color: product.requiresReturn
                          ? AppPalette.rose
                          : AppPalette.gold,
                    ),
                    _ProductMetaChip(
                      label: _categoryLabel(product.category),
                      icon: _categoryIcon(product.category),
                      color: tint,
                      onTap: onCategoryTap,
                    ),
                    if (!hasPreview)
                      const StatusBadge(
                        label: 'Место под фото',
                        color: AppPalette.gold,
                      ),
                    AnimatedSwitcher(
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 220),
                        reduced: Duration.zero,
                      ),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: inCartCount > 0
                          ? StatusBadge(
                              key: ValueKey<int>(inCartCount),
                              label: 'В корзине: $inCartCount',
                              color: AppPalette.mint,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  product.requiresReturn
                      ? 'После мероприятия позиция возвращается на склад.'
                      : 'Продажный товар остаётся у клиента после получения.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Остаток: ${product.stock} ${product.unitLabel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: stockRatio,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              color: tint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Text(
                        product.stock <= 2 ? 'Мало' : 'OK',
                        style: TextStyle(
                          color: product.stock <= 2
                              ? AppPalette.danger
                              : AppPalette.mint,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: product.stock <= 0
                            ? [
                                AppPalette.plum.withValues(alpha: 0.60),
                                AppPalette.plum.withValues(alpha: 0.36),
                              ]
                            : [AppPalette.rose, AppPalette.peach],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: product.stock <= 0
                          ? null
                          : () {
                              app.addToCart(product);
                              showInfoSnackBar(
                                context,
                                '${product.title} добавлен в корзину.',
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      icon: Icon(
                        inCartCount > 0
                            ? Icons.add_circle_outline_rounded
                            : Icons.add_shopping_cart_rounded,
                      ),
                      label: AnimatedSwitcher(
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 220),
                          reduced: Duration.zero,
                        ),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.16),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          product.stock <= 0
                              ? 'Нет в наличии'
                              : inCartCount > 0
                              ? 'Добавить ещё'
                              : 'Добавить',
                          key: ValueKey<String>(
                            product.stock <= 0
                                ? 'out'
                                : inCartCount > 0
                                ? 'more'
                                : 'add',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
// ignore: unused_element
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    this.highlight = false,
    this.onKindTap,
    this.onCategoryTap,
  });

  final Product product;
  final bool highlight;
  final VoidCallback? onKindTap;
  final VoidCallback? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final tint = parseHexColor(product.tint);
    final inCartCount = app.cart
        .where((entry) => entry.product.id == product.id)
        .fold(0, (sum, entry) => sum + entry.quantity);
    final stockDenominator = (product.stock + 4).clamp(1, 24);
    final stockRatio = (product.stock / stockDenominator).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: HoverLift(
        child: GlassPanel(
          borderColor: tint.withValues(alpha: highlight ? 0.30 : 0.18),
          padding: const EdgeInsets.all(0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: highlight
                    ? [
                        tint.withValues(alpha: 0.14),
                        AppPalette.panel.withValues(alpha: 0.92),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductPreview(product: product, tint: tint),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.66),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: tint.withValues(alpha: 0.14),
                      ),
                      child: Text(
                        rubles(product.price),
                        style: TextStyle(
                          color: tint,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ActionChip(
                      label: product.requiresReturn
                          ? 'Возвратная тара'
                          : 'Продажа',
                      onPressed: onKindTap,
                      avatar: Icon(
                        product.requiresReturn
                            ? Icons.assignment_return_rounded
                            : Icons.shopping_bag_rounded,
                        size: 16,
                        color: product.requiresReturn
                            ? AppPalette.rose
                            : AppPalette.gold,
                      ),
                    ),
                    ActionChip(
                      label: Text(_categoryLabel(product.category)),
                      avatar: Icon(
                        _categoryIcon(product.category),
                        size: 16,
                        color: tint,
                      ),
                      onPressed: onCategoryTap,
                    ),
                    AnimatedSwitcher(
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 220),
                        reduced: Duration.zero,
                      ),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: inCartCount > 0
                          ? StatusBadge(
                              key: ValueKey<int>(inCartCount),
                              label: 'В корзине: $inCartCount',
                              color: AppPalette.mint,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  product.requiresReturn
                      ? 'После мероприятия позиция возвращается на склад.'
                      : 'Продажный товар: остаётся у клиента после получения.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Остаток: ${product.stock} ${product.unitLabel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: stockRatio,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              color: tint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Text(
                        product.stock <= 2 ? 'Мало' : 'OK',
                        style: TextStyle(
                          color: product.stock <= 2
                              ? AppPalette.danger
                              : AppPalette.mint,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: product.stock <= 0
                            ? [
                                AppPalette.plum.withValues(alpha: 0.60),
                                AppPalette.plum.withValues(alpha: 0.36),
                              ]
                            : [AppPalette.rose, AppPalette.peach],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: product.stock <= 0
                          ? null
                          : () {
                              app.addToCart(product);
                              showInfoSnackBar(
                                context,
                                '${product.title} добавлен в корзину.',
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      icon: Icon(
                        inCartCount > 0
                            ? Icons.add_circle_outline_rounded
                            : Icons.add_shopping_cart_rounded,
                      ),
                      label: AnimatedSwitcher(
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 220),
                          reduced: Duration.zero,
                        ),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.16),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          product.stock <= 0
                              ? 'Нет в наличии'
                              : inCartCount > 0
                              ? 'Добавить ещё'
                              : 'Добавить',
                          key: ValueKey<String>(
                            product.stock <= 0
                                ? 'out'
                                : inCartCount > 0
                                ? 'more'
                                : 'add',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
*/

class _ProductPreview extends StatelessWidget {
  const _ProductPreview({required this.product, required this.tint});

  final Product product;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
                    _PreviewFallback(tint: tint, product: product),
              )
            : _PreviewFallback(tint: tint, product: product),
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({required this.tint, required this.product});

  final Color tint;
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Icon(_categoryIcon(product.category), color: tint, size: 34),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.black.withValues(alpha: 0.22),
            child: Text(
              'Превью',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartSummaryHero extends StatelessWidget {
  const _CartSummaryHero({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final returnItems = app.cart.fold(
      0,
      (sum, entry) => sum + (entry.product.requiresReturn ? entry.quantity : 0),
    );
    final saleItems = app.cart.fold(
      0,
      (sum, entry) => sum + (entry.product.requiresReturn ? 0 : entry.quantity),
    );

    return GlassPanel(
      padding: const EdgeInsets.all(0),
      borderColor: AppPalette.rose.withValues(alpha: 0.18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppPalette.panelStrong.withValues(alpha: 0.96),
              AppPalette.rose.withValues(alpha: 0.12),
              AppPalette.peach.withValues(alpha: 0.08),
            ],
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              eyebrow: 'Cart overview',
              title: 'Почти готовый заказ',
              subtitle:
                  'До оплаты всё видно по-честному: где возвратная тара, где продажный товар и сколько позиций уходит в отгрузку.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricChip(
                  label: 'Всего в корзине',
                  value: '${app.cartItemsCount} шт',
                  color: AppPalette.rose,
                ),
                MetricChip(
                  label: 'Возвратные',
                  value: '$returnItems шт',
                  color: AppPalette.peach,
                ),
                MetricChip(
                  label: 'Продажа',
                  value: '$saleItems шт',
                  color: AppPalette.gold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppPalette.peach.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 18, color: AppPalette.text),
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.entry});

  final CartEntry entry;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final tint = parseHexColor(entry.product.tint);

    return RepaintBoundary(
      child: HoverLift(
        hoverOffset: 6,
        child: GlassPanel(
          borderColor: tint.withValues(alpha: 0.18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: tint.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      _categoryIcon(entry.product.category),
                      color: tint,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.product.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.product.subtitle,
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
                    rubles(entry.subtotal),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusBadge(
                    label: entry.product.requiresReturn
                        ? 'Возвратная тара'
                        : 'Продажный товар',
                    color: entry.product.requiresReturn
                        ? AppPalette.rose
                        : AppPalette.gold,
                  ),
                  StatusBadge(
                    label: '${entry.quantity} ${entry.product.unitLabel}',
                    color: tint,
                  ),
                  StatusBadge(
                    label: rubles(entry.product.price),
                    color: AppPalette.mint,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _QuantityButton(
                    icon: Icons.remove_rounded,
                    onPressed: () => app.updateCartQuantity(
                      entry.product.id,
                      entry.quantity - 1,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 180),
                        reduced: Duration.zero,
                      ),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        '${entry.quantity}',
                        key: ValueKey<int>(entry.quantity),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add_rounded,
                    onPressed: () => app.updateCartQuantity(
                      entry.product.id,
                      entry.quantity + 1,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => app.removeFromCart(entry.product.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Удалить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartTab extends StatelessWidget {
  const _CartTab({
    required this.onBrowseCatalog,
    required this.onOpenAssistant,
  });

  final VoidCallback onBrowseCatalog;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RevealOnMount(child: _CartSummaryHero(app: app)),
          const SizedBox(height: 16),
          if (app.cart.isEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EmptyStatePanel(
                    title: 'Корзина пока пустая',
                    message:
                        'Добавьте позиции из каталога или соберите готовый сценарий через помощник заказа.',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onBrowseCatalog,
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text('Открыть каталог'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenAssistant,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Открыть помощник'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            ...app.cart.asMap().entries.map(
              (entry) => RevealOnMount(
                delay: Duration(milliseconds: 80 + (entry.key * 55)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CartLine(entry: entry.value),
                ),
              ),
            ),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    eyebrow: 'Final step',
                    title: 'Итог перед оплатой',
                    subtitle:
                        'Проверь состав заказа: аренда и продажа уже различаются, а номер карты будет безопасно замаскирован.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MetricChip(
                          label: 'Количество',
                          value: '${app.cartItemsCount} шт',
                          color: AppPalette.rose,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricChip(
                          label: 'К оплате',
                          value: rubles(app.cartTotal),
                          color: AppPalette.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: AppPalette.peach.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Оформление карты остаётся красивым, а в backend идёт только безопасная маска номера.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.45,
                            ),
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
                          onPressed: app.clearCart,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Очистить'),
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
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PaymentScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            icon: const Icon(Icons.lock_rounded),
                            label: const Text('К оплате'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.onBrowseCatalog,
    required this.onOpenAssistant,
  });

  final VoidCallback onBrowseCatalog;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final user = app.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            onPressed: app.refreshOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassPanel(
            borderColor: AppPalette.gold.withValues(alpha: 0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [AppPalette.rose, AppPalette.peach],
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Без имени',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '@${user?.login ?? 'guest'}',
                            style: const TextStyle(
                              color: AppPalette.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user != null)
                      StatusBadge(
                        label: user.role.title,
                        color: AppPalette.rose,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  user?.phone.isNotEmpty == true
                      ? user!.phone
                      : 'Телефон пока не указан',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
                ),
                if (user?.email.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    user!.email,
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
                    if (user != null)
                      StatusBadge(
                        label: user.isEmailVerified
                            ? 'Email подтвержден'
                            : 'Email не подтвержден',
                        color: user.isEmailVerified
                            ? AppPalette.mint
                            : AppPalette.peach,
                      ),
                    if (user != null)
                      StatusBadge(
                        label: user.isPhoneVerified
                            ? 'Телефон подтвержден'
                            : 'Телефон не подтвержден',
                        color: user.isPhoneVerified
                            ? AppPalette.mint
                            : AppPalette.peach,
                      ),
                  ],
                ),
                if (user?.risk.isBlocked == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: AppPalette.danger.withValues(alpha: 0.10),
                      border: Border.all(
                        color: AppPalette.danger.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.gpp_bad_outlined,
                              color: AppPalette.danger,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Новые заказы временно ограничены',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user!.risk.blockReason ??
                              'Сначала закрой активную аренду с возвратной тарой.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                            height: 1.45,
                          ),
                        ),
                        if (user.risk.overdueOrderCodes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Проблемные заказы: ${user.risk.overdueOrderCodes.join(', ')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    MetricChip(
                      label: 'Заказов',
                      value: '${app.orders.length}',
                      color: AppPalette.rose,
                    ),
                    MetricChip(
                      label: 'Активных',
                      value: '${app.activeOrders.length}',
                      color: AppPalette.peach,
                    ),
                    MetricChip(
                      label: 'Завершённых',
                      value: '${app.completedOrders.length}',
                      color: AppPalette.mint,
                    ),
                    if (user?.risk.overdueActiveOrders != null &&
                        user!.risk.overdueActiveOrders > 0)
                      MetricChip(
                        label: 'Просрочено',
                        value: '${user.risk.overdueActiveOrders}',
                        color: AppPalette.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: app.logout,
                    child: const Text('Выйти из аккаунта'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeading(
            eyebrow: 'Orders',
            title: 'Мои заказы',
            subtitle:
                'История заказов, QR-пропуск, статусы договора и оплаты остаются в одном месте для клиента и команды.',
          ),
          const SizedBox(height: 12),
          if (app.orders.isEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EmptyStatePanel(
                    title: 'Заказов ещё нет',
                    message:
                        'После первого заказа здесь появятся история, статусы, договор и QR-пропуск для выдачи.',
                    icon: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onBrowseCatalog,
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text('Перейти в каталог'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenAssistant,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Подобрать сценарий'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ...app.orders.map(
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
                                fontWeight: FontWeight.w800,
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          StatusBadge(
                            label: order.deliveryType == 'pickup'
                                ? 'Самовывоз'
                                : 'Доставка',
                            color: AppPalette.gold,
                          ),
                          StatusBadge(
                            label:
                                order.items.any((item) => item.requiresReturn)
                                ? 'Есть возврат'
                                : 'Только продажа',
                            color:
                                order.items.any((item) => item.requiresReturn)
                                ? AppPalette.rose
                                : AppPalette.mint,
                          ),
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        order.location,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Сумма: ${rubles(order.totalAmount)} • ${order.itemCount} поз.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создан: ${_formatOrderStamp(order.createdAt)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                        ),
                      ),
                      if (order.paymentMask.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Карта: ${order.paymentMask}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                          ),
                        ),
                      ],
                      if (order.issuedSerials.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Выданные серийники: ${order.issuedSerials.join(', ')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                          ),
                        ),
                      ],
                      if (order.contractId?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final contract = await app.getOrderContract(
                                  order.id,
                                );
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
                                  fallback:
                                      'Не удалось открыть договор. Попробуйте ещё раз.',
                                );
                              }
                            },
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Договор'),
                          ),
                        ),
                      ],
                      if (_canShowOrderPass(order)) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderPassScreen(order: order),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text('Открыть QR-пропуск'),
                          ),
                        ),
                      ],
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

String _categoryLabel(String category) {
  switch (category) {
    case 'gas':
      return 'Гелий и баллоны';
    case 'equipment':
      return 'Оборудование';
    case 'consumable':
      return 'Расходники';
    default:
      return 'Каталог';
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'gas':
      return Icons.celebration_outlined;
    case 'equipment':
      return Icons.build_circle_outlined;
    case 'consumable':
      return Icons.inventory_2_outlined;
    default:
      return Icons.widgets_outlined;
  }
}

String _formatOrderStamp(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} • '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

bool _canShowOrderPass(OrderModel order) {
  return order.paymentStatus == 'paid' ||
      order.status == OrderStatus.paid ||
      order.status == OrderStatus.active ||
      order.status == OrderStatus.completed;
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

Color _statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.draft:
      return AppPalette.plum;
    case OrderStatus.awaitingSignature:
      return AppPalette.gold;
    case OrderStatus.awaitingPayment:
      return AppPalette.peach;
    case OrderStatus.active:
      return AppPalette.peach;
    case OrderStatus.completed:
      return AppPalette.mint;
    case OrderStatus.paid:
      return AppPalette.rose;
    case OrderStatus.blocked:
      return AppPalette.danger;
  }
}
