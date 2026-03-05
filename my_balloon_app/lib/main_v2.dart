import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
// ПЛАГИН ДЛЯ ВСТРОЕННОГО YOUTUBE ПЛЕЕРА
import 'package:youtube_player_iframe/youtube_player_iframe.dart'; 
// --- ГЛОБАЛЬНЫЕ ДАННЫЕ (БАЗА) ---
int totalCylindersInStock = 20; // Всего баллонов в твоем парке
List<CartItem> cart = [];
List<Order> orderHistory = [];
bool isLoggedIn = false;
String currentUserName = "";
String currentUserEmail = "";
String selectedLocation = "Не выбрано";

// --- НОВЫЕ ПОЛЯ ДЛЯ АДМИНКИ ---
String promoVideoId = "OjxoHgnaNL8"; // Твоё промо
String safetyVideoId = "OjxoHgnaNL8"; // Инструкция редуктора

// Список товаров теперь глобальный, чтобы админка могла его менять
List<GasCylinder> globalProducts = [
  GasCylinder(
    title: "Гелий 10Л (Коричневый)",
    shortDescription: "Аттестован. Гелий марки 'Б'.",
    fullDescription: "Стальной баллон 10 литров. ГОСТ 949-73. Идеален для надувания до 100 шаров. Возврат тары обязателен.",
    priceInt: 3000,
    imageUrls: ["https://i.postimg.cc/KjRcWtLM/19e10b22-12e6-464b-950b-84ace40f032e.png"],
  ),
  GasCylinder(
    title: "Проф. редуктор",
    shortDescription: "С нажимным клапаном.",
    fullDescription: "Обеспечивает мягкую подачу газа. Манометр для контроля давления. Экономия гелия до 20%.",
    priceInt: 3500,
    imageUrls: ["https://i.postimg.cc/wvWTFwtj/83c127b5-e691-4d52-8f52-b17e86461725.png"],
  ),
  GasCylinder(
    title: "Набор 'Праздник'",
    shortDescription: "10л + 50 шаров + Лента.",
    fullDescription: "Готовое решение: аренда баллона 10л, 50 шаров пастель и лента 100м.",
    priceInt: 5500,
    imageUrls: ["https://i.postimg.cc/Bbgy2ztN/Gemini_Generated_Image_agw17tagw17tagw1.png"],
  ),
];
void main() => runApp(const GasRentApp());

// НОВАЯ ФУНКЦИЯ: Теперь она открывает не браузер, а наш экран с плеером!
void launchYouTubeVideo(String videoId, BuildContext context) {
  Navigator.push(
    context, 
    MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoId: videoId))
  );
}
class GasRentApp extends StatelessWidget {
  const GasRentApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Express Pro',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.trackpad},
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A), 
          secondary: const Color(0xFFF59E0B), 
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        // Убрали проблемный cardTheme, теперь ошибки в начале не будет
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      builder: (context, child) {
        return Container(
          color: const Color(0xFFE2E8F0),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: ClipRRect(child: child!),
          ),
        );
      },
      home: const HomePage(),
    );
  }
}

// --- МОДЕЛИ ---
class GasCylinder {
  final String title, shortDescription, fullDescription;
  final int priceInt;
  final List<String> imageUrls;
  GasCylinder({required this.title, required this.shortDescription, required this.fullDescription, required this.priceInt, required this.imageUrls});
}

class CartItem {
  final GasCylinder product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class Order {
  final String id;
  final String date;
  final int totalAmount;
  final int itemCount; // НОВОЕ ПОЛЕ: сколько баллонов в заказе
  final String customerName;
  final String location;
  final String qrCode;
  final String contractText;
  String status = "Оплачен"; 

  Order({
    required this.id, 
    required this.date, 
    required this.totalAmount, 
    required this.itemCount, // Обязательный параметр
    required this.customerName,
    required this.location,
    required this.qrCode,
    required this.contractText,
  });
}

// --- ГЛАВНЫЙ ЭКРАН ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<GasCylinder> getProducts() => [
    GasCylinder(
      title: "Гелий 10Л (Коричневый)",
      shortDescription: "Аттестован. Гелий марки 'Б'.",
      fullDescription: "Стальной баллон 10 литров. ГОСТ 949-73. Идеален для надувания до 100 шаров. Возврат тары обязателен.",
      priceInt: 3000,
      imageUrls: ["https://i.postimg.cc/KjRcWtLM/19e10b22-12e6-464b-950b-84ace40f032e.png"],
    ),
    GasCylinder(
      title: "Проф. редуктор",
      shortDescription: "С нажимным клапаном.",
      fullDescription: "Обеспечивает мягкую подачу газа. Манометр для контроля давления. Экономия гелия до 20%.",
      priceInt: 3500,
      imageUrls: ["https://i.postimg.cc/wvWTFwtj/83c127b5-e691-4d52-8f52-b17e86461725.png"],
    ),
    GasCylinder(
      title: "Набор 'Праздник'",
      shortDescription: "10л + 50 шаров + Лента.",
      fullDescription: "Готовое решение: аренда баллона 10л, 50 шаров пастель и лента 100м.",
      priceInt: 5500,
      imageUrls: ["https://i.postimg.cc/Bbgy2ztN/Gemini_Generated_Image_agw17tagw17tagw1.png"],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GAS EXPRESS"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(isLoggedIn ? Icons.account_circle : Icons.person_outline, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => isLoggedIn ? const ProfilePage() : const AuthPage())).then((_) => setState(() {})),
            ),
          ),
        ],
      ),
      body: _currentIndex == 0 ? buildStore(getProducts()) : const AssistantPage(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 20)],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            if (i == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())).then((_) => setState(() {}));
            } else {
              setState(() => _currentIndex = i);
            }
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x33F59E0B),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: "Маркет"),
            NavigationDestination(icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: "Помощник"),
            NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: "Корзина"),
          ],
        ),
      ),
    );
  }

  Widget buildStore(List<GasCylinder> products) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- ПРОМО-БАННЕР С ВИДЕО ---
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: const DecorationImage(
              image: NetworkImage("https://images.unsplash.com/photo-1530103862676-de8c9debad1d?q=80&w=1000"), // Обложка
              fit: BoxFit.cover,
            ),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 5))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20))),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.9), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text("Узнайте, как работает сервис", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    // ПЕРВОЕ ВИДЕО: Твой промо-ролик про шары
                    launchYouTubeVideo('OjxoHgnaNL8', context); 
                  },
                ),
              )
            ],
          ),
        ),
        
        const Text("Каталог оборудования", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),

        // ВЫВОД ТОВАРОВ
        ...products.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 15, offset: Offset(0, 5))],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: item))).then((_) => setState(() {})),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 180, width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    child: Hero(tag: item.title, child: Image.network(item.imageUrls.first, fit: BoxFit.contain)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                          const SizedBox(height: 6),
                          Text(item.shortDescription, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        ])),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text("${item.priceInt} ₽", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: Size.zero),
                            onPressed: () {
                              setState(() {
                                final ex = cart.where((c) => c.product.title == item.title);
                                if (ex.isEmpty) cart.add(CartItem(product: item)); else ex.first.quantity++;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Товар добавлен!"), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), backgroundColor: const Color(0xFF0F172A)));
                            },
                            child: const Icon(Icons.add, size: 20),
                          )
                        ])
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ],
    );
  }
}
// --- СТРАНИЦА ПОМОЩНИК ---
// --- ОБНОВЛЕННЫЙ ПОМОЩНИК МАСТЕРА (ИНСТРУКЦИИ + КАЛЬКУЛЯТОР) ---
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  double _balloonsCount = 50;
  String _selectedType = 'Standard';

  // Расход гелия (литры на 1 шар)
  final Map<String, double> _consumption = {
    'Mini': 8.0,      // Латекс 10" (25 см)
    'Standard': 14.0, // Латекс 12" (30 см)
    'Foil': 16.0,     // Фольга 18" (45 см)
  };

  int _calculateCylinders() {
    double totalHeliumNeeded = _balloonsCount * _consumption[_selectedType]!;
    // В 10л баллоне при 150 атм находится ~1500 литров гелия
    return (totalHeliumNeeded / 1500).ceil();
  }

  @override
  Widget build(BuildContext context) {
    int cylinders = _calculateCylinders();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Центр управления", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // --- 1. КАРТОЧКА: ВИДЕОИНСТРУКЦИЯ (В ТВОЕМ СТИЛЕ) ---
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20)], //
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.video_library_outlined, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 10),
                  Text("Сборка редуктора", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                const Text(
                  "Видео-гайд: как безопасно подключить профессиональный редуктор к 10л баллону и проверить утечки.",
                  style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      foregroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => launchYouTubeVideo('OjxoHgnaNL8', context), //
                    icon: const Icon(Icons.play_circle_fill, size: 20),
                    label: const Text("СМОТРЕТЬ ИНСТРУКЦИЮ"),
                  ),
                ),
              ],
            ),
          ),const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text("ДОБАВИТЬ РАСЧЕТ В КОРЗИНУ"),
              onPressed: () {
                setState(() {
                  // Ищем товар "Гелий" в твоем списке globalProducts
                  var helium = globalProducts.firstWhere((p) => p.title.contains("Гелий"));
                  for (int i = 0; i < cylinders; i++) {
                    cart.add(CartItem(product: helium));
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("В корзину добавлено $cylinders баллона(ов)")));
              },
            ),
          ),

          // --- 2. КАРТОЧКА: КАЛЬКУЛЯТОР ГЕЛИЯ ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20)],
            ),
            child: Column(
              children: [
                const Align(alignment: Alignment.centerLeft, child: Text("Тип и размер шаров:", style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Mini', label: Text("10\""), icon: Icon(Icons.wb_sunny_outlined)),
                    ButtonSegment(value: 'Standard', label: Text("12\""), icon: Icon(Icons.circle)),
                    ButtonSegment(value: 'Foil', label: Text("18\""), icon: Icon(Icons.star_outline)),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (val) => setState(() => _selectedType = val.first),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Количество:", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  Text("${_balloonsCount.toInt()} шт.", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value: _balloonsCount, min: 5, max: 500, divisions: 99,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (v) => setState(() => _balloonsCount = v),
                ),
                const Divider(height: 40),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Нужно баллонов (10л):", style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                    child: Text("$cylinders шт.", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 40),
          const Text("Справочник мастера", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // --- 3. ИНФОРМАЦИОННЫЕ КАРТОЧКИ (ТЕХНИЧЕСКИЕ ПРАВИЛА) ---
          _infoCard("Защита оборудования", Icons.shield_outlined, [
            "• При перевозке 10л баллона всегда накручивайте защитный колпак.",
            "• Оставляйте остаточное давление 0.5 атм, чтобы в баллон не попала влага.",
          ]),
          
          _infoCard("Работа с редуктором", Icons.handyman_outlined, [
            "• Перед работой проверьте соединение мыльным раствором на отсутствие утечек.",
            "• Открывайте вентиль плавно, не стойте напротив манометра.",
          ]),

          _infoCard("Советы по экономии", Icons.tips_and_updates_outlined, [
            "• Не передувайте латекс (форма груши увеличивает расход гелия на 20%).",
            "• Фольгированные шары надувайте медленно, чтобы избежать разрыва швов.",
          ]),
        ],
      ),
    );
  }

  Widget _infoCard(String title, IconData icon, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l, style: const TextStyle(color: Colors.black87, height: 1.4)),
          )),
        ],
      ),
    );
  }
}
// --- КОРЗИНА ---
class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int get total => cart.fold(0, (sum, item) => sum + (item.product.priceInt * item.quantity));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Корзина")),
      body: cart.isEmpty 
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_basket_outlined, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text("Корзина пуста", style: TextStyle(fontSize: 20, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          ]))
        : Column(children: [
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: cart.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (c, i) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(width: 60, height: 60, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: Image.network(cart[i].product.imageUrls.first)),
                  title: Text(cart[i].product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${cart[i].product.priceInt} ₽", style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => cart[i].quantity > 1 ? cart[i].quantity-- : cart.removeAt(i))),
                    Text("${cart[i].quantity}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => cart[i].quantity++)),
                  ]),
                ),
              ),
            )),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Итого к оплате:", style: TextStyle(fontSize: 16, color: Colors.grey)), Text("$total ₽", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))]),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { if (!isLoggedIn) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Сначала войдите в профиль"))); return; } Navigator.push(context, MaterialPageRoute(builder: (_) => ContractPage(totalAmount: total))); }, child: const Text("Оформить заказ")))
              ]),
            )
          ]),
    );
  }
}

// --- ДОГОВОР ---
class ContractPage extends StatefulWidget {
  final int totalAmount;
  const ContractPage({super.key, required this.totalAmount});
  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  bool _isSigned = false;
  final String contractText = """
ДОГОВОР АРЕНДЫ МНОГООБОРОТНОЙ ТАРЫ И ПОСТАВКИ ГАЗА

1. ПРЕДМЕТ ДОГОВОРА
Арендодатель передает, а Арендатор принимает во временное пользование многооборотную тару (стальной баллон 10л) и приобретает технический газ (гелий). Передача тары оформляется сканированием QR-кода.

2. ПРАВА И ОБЯЗАННОСТИ СТОРОН
2.1. Арендатор обязан поддерживать баллон в технически исправном состоянии.
2.2. Арендатор обязуется вернуть баллон в течение 3 (трех) суток.

3. ОТВЕТСТВЕННОСТЬ
В случае утери или порчи баллона, Арендатор выплачивает штраф 15 000 рублей.

4. ПРОЧИЕ УСЛОВИЯ
Документ подписан простой электронной подписью (ЭП).
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Подписание"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Скачать PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Договор загружается на устройство...")));
            },
          )
        ],
      ),
      body: Column(children: [
        Expanded(child: Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: SingleChildScrollView(child: Column(children: [
          const Icon(Icons.gavel, size: 50, color: Color(0xFF0F172A)),
          const SizedBox(height: 20),
          const Text("Договор аренды", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const Divider(height: 40),
          Text(contractText, style: const TextStyle(height: 1.5, fontSize: 16)),
          const SizedBox(height: 40),
          if (_isSigned) Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF59E0B), width: 2), borderRadius: BorderRadius.circular(10)), child: const Text("ПОДПИСАНО ЭП", style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)))
        ])))),
        Padding(padding: const EdgeInsets.all(24), child: !_isSigned 
          ? SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => setState(() => _isSigned = true), child: const Text("Подписать через Госуслуги"))) 
          : SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocationPage(totalAmount: widget.totalAmount, contractText: contractText))), child: const Text("Выбрать доставку"))))
      ]),
    );
  }
}

// --- ЛОГИСТИКА ---
class LocationPage extends StatefulWidget {
  final int totalAmount;
  final String contractText;
  const LocationPage({super.key, required this.totalAmount, required this.contractText});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  int _m = 0; String _city = "Москва";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Получение")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(20), child: SegmentedButton<int>(
          segments: const [ButtonSegment(value: 0, label: Text("Самовывоз"), icon: Icon(Icons.store)), ButtonSegment(value: 1, label: Text("Курьер"), icon: Icon(Icons.local_shipping))], 
          selected: {_m}, 
          onSelectionChanged: (s) => setState(() => _m = s.first))
        ),
        Expanded(child: _m == 0 
          ? ListView(padding: const EdgeInsets.all(20), children: [DropdownButtonFormField(decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Город"), value: _city, items: ["Москва", "Казань"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _city = v!)), const SizedBox(height: 20), RadioListTile(activeColor: const Color(0xFFF59E0B), title: const Text("Центральный склад (ул. Газовая, 1)"), value: "Склад", groupValue: selectedLocation, onChanged: (v) => setState(() => selectedLocation = v!))]) 
          : const Padding(padding: EdgeInsets.all(20), child: TextField(decoration: InputDecoration(border: OutlineInputBorder(), labelText: "Адрес доставки", prefixIcon: Icon(Icons.map))))),
        Padding(
  padding: const EdgeInsets.all(24), 
  child: SizedBox(
    width: double.infinity, 
    height: 55, 
    child: ElevatedButton(
      // Сначала вызываем проверку безопасности
      onPressed: () => showSafetyDialog(context, () {
        // Если клиент нажал "Согласен", идем на оплату
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => PaymentMethodPage(
            amount: widget.totalAmount, 
            contractText: widget.contractText
          ))
        );
      }), 
      child: const Text("Перейти к оплате"),
    ),
  ),
)
      ]),
    );
  }
}

// --- БЛОК ОПЛАТЫ: ИСПРАВЛЕННАЯ ВЕРСИЯ ---

class PaymentMethodPage extends StatelessWidget {
  final int amount;
  final String contractText;
  const PaymentMethodPage({super.key, required this.amount, required this.contractText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Оплата")),
      body: Padding(
        padding: const EdgeInsets.all(24), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("К оплате", style: TextStyle(color: Colors.grey)),
          Text("$amount ₽", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 40),
          buildMethod(context, "Банковская карта", Icons.credit_card, const Color(0xFF0F172A), 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardPaymentPage(amount: amount, contractText: contractText)))),
          buildMethod(context, "СБП (Быстрый платеж)", Icons.qr_code, Colors.purple, 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => SbpPaymentPage(amount: amount, contractText: contractText)))),
        ])
      ),
    );
  }

  Widget buildMethod(BuildContext ctx, String t, IconData i, Color c, VoidCallback tap) => 
    Container(
      margin: const EdgeInsets.only(bottom: 16), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), 
      child: ListTile(contentPadding: const EdgeInsets.all(16), onTap: tap, leading: Icon(i, color: c, size: 32), 
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.arrow_forward_ios, size: 16))
    );
}

class SbpPaymentPage extends StatelessWidget {
  final int amount;
  final String contractText;
  const SbpPaymentPage({super.key, required this.amount, required this.contractText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Оплата СБП")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20)]), child: const Icon(Icons.qr_code_2, size: 200)),
        const SizedBox(height: 40),
        SizedBox(
          width: 200, height: 50, 
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)), 
            onPressed: () { 
              String orderId = "№${DateTime.now().millisecond}";
              int count = cart.length; // Считаем баллоны ПЕРЕД очисткой корзины
              
              totalCylindersInStock -= count; // Списание со склада

              orderHistory.insert(0, Order(
                id: orderId, 
                date: "Сегодня", 
                totalAmount: amount, 
                itemCount: count, // Передаем кол-во для корректного возврата
                location: selectedLocation, 
                qrCode: orderId, 
                contractText: contractText,
                customerName: currentUserName
              )..status = "Оплачен"); // Ждёт выдачи курьером

              cart.clear(); 
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SuccessPage()), (r) => false);
            }, 
            child: const Text("Я оплатил")
          )
        )
      ])),
    );
  }
}

class CardPaymentPage extends StatefulWidget {
  final int amount;
  final String contractText;
  const CardPaymentPage({super.key, required this.amount, required this.contractText});
  @override
  State<CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<CardPaymentPage> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Оплата картой")),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        const TextField(decoration: InputDecoration(border: OutlineInputBorder(), labelText: "Номер карты", prefixIcon: Icon(Icons.credit_card))),
        const SizedBox(height: 20),
        const Row(children: [Expanded(child: TextField(decoration: InputDecoration(border: OutlineInputBorder(), labelText: "MM/YY"))), SizedBox(width: 20), Expanded(child: TextField(decoration: InputDecoration(border: OutlineInputBorder(), labelText: "CVC/CVV")))]),
        const Spacer(),
        SizedBox(
          width: double.infinity, height: 55, 
          child: ElevatedButton(
            onPressed: () async {
              setState(() => _loading = true); 
              await Future.delayed(const Duration(seconds: 1)); 
              
              String orderId = "№${DateTime.now().millisecond}";
              int count = cart.length; // Фиксируем количество баллонов
              
              totalCylindersInStock -= count; // Списываем со склада

              orderHistory.insert(0, Order(
                id: orderId, 
                date: "Сегодня", 
                totalAmount: widget.amount, 
                itemCount: count, // Запоминаем кол-во в заказе
                location: selectedLocation, 
                qrCode: orderId, 
                contractText: widget.contractText,
                customerName: currentUserName
              )..status = "Оплачен"); // Теперь статус корректный

              cart.clear(); 

              if (!mounted) return; 
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SuccessPage()), (r) => false);
            }, 
            child: _loading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : Text("Оплатить ${widget.amount} ₽")
          )
        )
      ])),
    );
  }
}

// --- УСПЕХ ---
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle_outline, size: 120, color: Color(0xFF16A34A)),
      const SizedBox(height: 20),
      const Text("Заказ оплачен!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text("Спасибо за покупку", style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 50),
      SizedBox(width: 200, height: 50, child: OutlinedButton(onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (r) => false), child: const Text("В магазин")))
    ])));
  }
}

// --- РЕГИСТРАЦИЯ ---
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final n = TextEditingController(); final e = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Вход / Регистрация")),
      body: Padding(padding: const EdgeInsets.all(30), child: Column(children: [
        const Icon(Icons.lock_person, size: 80, color: Color(0xFF0F172A)),
        const SizedBox(height: 40),
        TextField(controller: n, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Ваше Имя", prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 20),
        TextField(controller: e, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Email", prefixIcon: Icon(Icons.email))),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationPage(name: n.text, email: e.text))), child: const Text("Продолжить"))),
      ])),
    );
  }
}

class VerificationPage extends StatelessWidget {
  final String name, email;
  const VerificationPage({super.key, required this.name, required this.email});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Подтверждение")),
      body: Padding(padding: const EdgeInsets.all(30), child: Column(children: [
        Text("Мы отправили код на $email", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 30),
        const TextField(textAlign: TextAlign.center, style: TextStyle(fontSize: 24, letterSpacing: 8), decoration: InputDecoration(border: OutlineInputBorder(), hintText: "0000")),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { 
          isLoggedIn = true; currentUserName = name; currentUserEmail = email;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthSuccessPage()), (r) => false);
        }, child: const Text("Войти"))),
      ])),
    );
  }
}

class AuthSuccessPage extends StatelessWidget {
  const AuthSuccessPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.celebration, size: 100, color: Color(0xFFF59E0B)),
        const SizedBox(height: 30),
        const Text("Вы успешно зарегистрировались в системе - добро пожаловать", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 50),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (r) => false), child: const Text("В магазин"))),
      ])),
    );
  }
}

// --- ПРОФИЛЬ ---
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Личный кабинет")),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(children: [
            CircleAvatar(
              radius: 30, 
              backgroundColor: const Color(0xFFF1F5F9), 
              child: Text(currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : "A", 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))
            ),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(currentUserName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
              Text(currentUserEmail, style: TextStyle(color: Colors.grey[600]))
            ])
          ]),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Text("Мои заказы", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (orderHistory.isEmpty) 
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Истории пока нет")))
              else
                ...orderHistory.map((order) => buildOrderTile(context, order)).toList(),
              const Divider(height: 40),
              // ТА САМАЯ КНОПКА
              // --- ТА САМАЯ КНОПКА (КУРЬЕР) ---
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(16)
                ),
                child: ListTile(
                  leading: const Icon(Icons.delivery_dining, color: Color(0xFFF59E0B)),
                  title: const Text("РЕЖИМ КУРЬЕРА", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Выдача баллонов и сканер"),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourierPage())),
                ),
              ),
              
              const SizedBox(height: 12), // Отступ между кнопками

              // --- КНОПКА АДМИН-ПАНЕЛИ (ТЕПЕРЬ ТУТ ВСЁ ВЕРНО) ---
              Container(
                decoration: BoxDecoration(
                  // Используем withValues для новых версий или withOpacity для старых
                  color: const Color(0xFF0F172A).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(16)
                ),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF0F172A)),
                  title: const Text("АДМИН-ПАНЕЛЬ", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Цены, видео и статистика продаж"),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelPage())),
                ),
              ),
            ], // <--- ВОТ ТЕПЕРЬ ЭТА СКОБКА ЕДИНСТВЕННАЯ И ЗАКРЫВАЕТ ВЕСЬ СПИСОК
          ),
        ),
      ]),
    );
  }

  Widget buildOrderTile(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text("Заказ ${order.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${order.totalAmount} ₽ • ${order.date}"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showOrderDetails(context, order),
      ),
    );
  }

  void _showOrderDetails(BuildContext ctx, Order order) {
    showDialog(context: ctx, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text("Заказ ${order.id}", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          // QR-код для курьера
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Image.network('https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${order.qrCode}'),
          ),
          const SizedBox(height: 15),
          Text("Статус: ${order.status}", 
            style: TextStyle(fontWeight: FontWeight.bold, color: order.status == "Активен" ? Colors.green : Colors.orange)),
          const Divider(height: 30),
          
          // КНОПКА: ИНСТРУКЦИЯ ПО БЕЗОПАСНОСТИ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
              onPressed: () => _viewSafety(ctx),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text("Инструкция по безопасности"),
            ),
          ),
          const SizedBox(height: 10),
          
          // КНОПКА: ДОГОВОР
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () { Navigator.pop(c); _viewDoc(ctx, order); }, 
              child: const Text("Договор аренды"),
            ),
          ),
        ],
      ),
    ));
  }
void showSafetyDialog(BuildContext context, VoidCallback onConfirm) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text("⚠️ ТЕХНИКА БЕЗОПАСНОСТИ"),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Для аренды 10л баллона подтвердите:"),
          SizedBox(height: 12),
          Text("• Наличие защитного колпака при перевозке"),
          Text("• Использование исправного редуктора"),
          Text("• Обязательство оставить 0.5 атм давления"),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")),
        ElevatedButton(onPressed: () { Navigator.pop(c); onConfirm(); }, child: const Text("ПОДТВЕРЖДАЮ")),
      ],
    ),
  );
}
  // ОКНО С ИНСТРУКЦИЕЙ (Тот самый "офигенный" вариант)
  void _viewSafety(BuildContext context) {
    showDialog(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red),
        SizedBox(width: 10),
        Text("Правила работы")
      ]),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _safetyItem("Хранение", "Держите баллон в вертикальном положении, вдали от прямых солнечных лучей и нагревательных приборов."),
            _safetyItem("Транспортировка", "Перевозите баллон с плотно закрытым вентилем и надетым защитным колпаком."),
            _safetyItem("Эксплуатация", "При надувании шаров используйте исправный редуктор. Открывайте вентиль плавно."),
            _safetyItem("Остаток гелия", "Не вырабатывайте газ «в ноль». Оставляйте давление 0.5 атм, чтобы избежать попадания влаги внутрь."),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Понятно"))],
    ));
  }

  Widget _safetyItem(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  void _viewDoc(BuildContext context, Order order) {
    showDialog(context: context, builder: (c) => Dialog.fullscreen(child: Scaffold(
      appBar: AppBar(title: const Text("Договор аренды")),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Text(order.contractText), const Spacer(), ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text("Закрыть"))])),
    )));
  }
}
// --- ЭКРАН КУРЬЕРА ---
class CourierPage extends StatefulWidget {
  const CourierPage({super.key});
  @override
  State<CourierPage> createState() => _CourierPageState();
}

class _CourierPageState extends State<CourierPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _bottleIdController = TextEditingController();
  Order? _foundOrder;

  void _findOrder() {
    setState(() {
      String query = _searchController.text.trim().replaceAll("№", ""); // Убираем лишние знаки
      try {
        // Ищем в глобальной истории заказов
        _foundOrder = orderHistory.firstWhere(
          (o) => o.id.replaceAll("№", "") == query
        );
      } catch (e) {
        _foundOrder = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Заказ не найден"))
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Выдача баллонов (Курьер)")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Поле поиска (как на твоем скрине)
            TextField(
              controller: _searchController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Введите ID заказа (например: 690)",
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _findOrder),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _findOrder(),
            ),
            const SizedBox(height: 24),

            if (_foundOrder != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Заказ ${_foundOrder!.id}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Text("Клиент: ${_foundOrder!.customerName}"),
                    Text("Количество: ${_foundOrder!.itemCount} шт."), //
                    Text(
                      "СТАТУС: ${_foundOrder!.status}",
                      style: TextStyle(
                        color: _foundOrder!.status == "Оплачен" ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- ЛОГИКА ВЫДАЧИ ---
                    if (_foundOrder!.status == "Оплачен") ...[
                      const Text("Для подтверждения введите номер баллона:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bottleIdController,
                        decoration: const InputDecoration(
                          hintText: "№ баллона (например: ГЛ-10-690)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                          onPressed: () {
                            if (_bottleIdController.text.isNotEmpty) {
                              setState(() {
                                // 1. МЕНЯЕМ СТАТУС НА АКТИВЕН
                                _foundOrder!.status = "Активен";
                              });
                              _bottleIdController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("✅ ЗАКАЗ ВЫДАН!"))
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Ошибка: введите номер баллона!"))
                              );
                            }
                          },
                          child: const Text("ПОДТВЕРДИТЬ И ВЫДАТЬ"),
                        ),
                      ),
                    ] else if (_foundOrder!.status == "Активен") ...[
                      const Center(
                        child: Text("✅ ЭТОТ ЗАКАЗ УЖЕ ВЫДАН", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// --- ДЕТАЛИ ТОВАРА (Баллоны 10л) ---
class ProductDetailsPage extends StatefulWidget {
  final GasCylinder product;
  const ProductDetailsPage({required this.product, super.key});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.title)),
      body: Column(
        children: [
          Expanded(child: Center(child: Image.network(widget.product.imageUrls[0]))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${widget.product.priceInt} ₽", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(widget.product.fullDescription),
              ],
            ),
          ),
          Container(
  padding: const EdgeInsets.all(20),
  child: ElevatedButton(
    onPressed: () {
      // 1. Обновляем состояние корзины
      setState(() {
        cart.add(CartItem(product: widget.product));
      });

      // 2. Настраиваем "умный" SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Добавлено в корзину!"),
          behavior: SnackBarBehavior.floating, // Делаем его плавающим
          // Поднимаем на 110 пикселей, чтобы кнопка «Оформить заказ» была видна и доступна
          margin: const EdgeInsets.only(bottom: 110, left: 20, right: 20),
          duration: const Duration(milliseconds: 600), // Чтобы не висел долго
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      );

      // Теперь здесь НЕТ Navigator.pop(context). 
      // Ты можешь добавлять баллоны один за другим, оставаясь на экране товара.
    }, 
    child: const Text("Добавить в корзину")
  ),
)
        ],
      ),
    );
  }
}
// --- ЭКРАН ВСТРОЕННОГО ВИДЕОПЛЕЕРА (Версия 4.0.4) ---
// --- ЭКРАН ВСТРОЕННОГО ВИДЕОПЛЕЕРА (Версия 4.x) ---
class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Видеоинструкция", style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: YoutubePlayer(controller: _controller),
      ),
    );
  }
}class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});
  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  @override
  Widget build(BuildContext context) {
    // --- РАСЧЕТ ДЕТАЛЬНОЙ СТАТИСТИКИ ---
    
    // Считаем только реальную выручку (Оплаченные, Активные и Завершенные заказы)
    int totalSales = orderHistory
        .where((o) => o.status != "Ожидает")
        .fold(0, (sum, item) => sum + item.totalAmount);

    // Считаем общее количество проданных/арендованных баллонов за всё время
    int totalCylindersRented = orderHistory
        .where((o) => o.status != "Ожидает")
        .fold(0, (sum, o) => sum + o.itemCount);

    // Считаем баллоны, которые сейчас "в пути" (Оплачены, но не выданы)
    int cylindersInTransit = orderHistory
        .where((o) => o.status == "Оплачен")
        .fold(0, (sum, o) => sum + o.itemCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("ПАНЕЛЬ УПРАВЛЕНИЯ"),
        backgroundColor: const Color(0xFF0F172A), 
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- БЛОК 1: ЦИФРОВАЯ СТАТИСТИКА ПРОДАЖ ---
          _buildSectionTitle("Контроль финансов и склада"),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), 
              borderRadius: BorderRadius.circular(20)
            ),
            child: Column(
              children: [
                _statusRow("Общая выручка:", "$totalSales ₽"),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Всего сделок:", "${orderHistory.length}"),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Баллонов выдано за всё время:", "$totalCylindersRented шт."),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Баллонов на складе сейчас:", "$totalCylindersInStock шт."),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Оплачено (ждут выдачи):", "$cylindersInTransit шт."),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- БЛОК 2: ТАБЛИЦА ТЕКУЩИХ ОПЕРАЦИЙ ---
          _buildSectionTitle("Текущие операции (Выдача/Возврат)"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("№")),
                  DataColumn(label: Text("Клиент")),
                  DataColumn(label: Text("Статус")),
                  DataColumn(label: Text("Действие")),
                ],
                rows: orderHistory.where((o) => o.status == "Активен" || o.status == "Оплачен").map((order) {
                  return DataRow(cells: [
                    DataCell(Text(order.id)),
                    DataCell(Text(order.customerName)),
                    DataCell(Text(order.status, style: TextStyle(color: order.status == "Оплачен" ? Colors.orange : Colors.green, fontWeight: FontWeight.bold))),
                    DataCell(
                      order.status == "Активен" 
                      ? ElevatedButton(
                          onPressed: () {
                            setState(() {
                              order.status = "Завершен";
                              totalCylindersInStock += order.itemCount; 
                            });
                          },
                          child: const Text("Принять возврат"),
                        )
                      : const Text("Ожидает выдачи", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // --- БЛОК 3: ИСТОРИЯ ПРОДАЖ (ЛОГ ТРАНЗАКЦИЙ) ---
          _buildSectionTitle("История всех продаж (Архив)"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: orderHistory.map((order) => ListTile(
                leading: const Icon(Icons.history_edu, color: Color(0xFF0F172A)),
                title: Text("${order.customerName} — ${order.totalAmount} ₽"),
                subtitle: Text("Заказ ${order.id} • ${order.itemCount} бал. • ${order.date}"),
                trailing: Text(order.status, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              )).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // --- БЛОК 4: РЕДАКТОР КАТАЛОГА ---
          _buildSectionTitle("Редактор товаров"),
          ...globalProducts.map((p) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Image.network(p.imageUrls[0], width: 40),
              title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${p.priceInt} ₽"),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)), onPressed: () => _editProduct(p)),
            ),
          )).toList(),
          
          const SizedBox(height: 32),
          _buildSectionTitle("Настройка видео-контента"),
          _videoEditTile("Промо-ролик", promoVideoId, (val) => setState(() => promoVideoId = val)),
          _videoEditTile("Инструкция редуктора", safetyVideoId, (val) => setState(() => safetyVideoId = val)),
        ], 
      ),
    );
  }
  
  // (Остальные методы _editProduct, _buildSectionTitle, _statusRow, _videoEditTile остаются без изменений)

  // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---

  void _editProduct(GasCylinder p) {
    final priceController = TextEditingController(text: p.priceInt.toString());
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Изменить цену: ${p.title}"),
      content: TextField(
        controller: priceController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: "Новая цена (₽)"),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Отмена")),
        ElevatedButton(onPressed: () {
          setState(() {
            int? newPrice = int.tryParse(priceController.text);
            if (newPrice != null) {
              int index = globalProducts.indexOf(p);
              globalProducts[index] = GasCylinder(
                title: p.title, shortDescription: p.shortDescription,
                fullDescription: p.fullDescription, priceInt: newPrice,
                imageUrls: p.imageUrls
              );
            }
          });
          Navigator.pop(c);
        }, child: const Text("Сохранить")),
      ],
    ));
  }

  Widget _buildSectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12), 
    child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))
  );

  Widget _statusRow(String t, String v) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(t, style: const TextStyle(color: Colors.white70)),
      Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    ],
  );

  Widget _videoEditTile(String label, String currentId, Function(String) onSave) {
    final controller = TextEditingController(text: currentId);
    return ListTile(
      title: Text(label),
      subtitle: Text("ID: $currentId"),
      trailing: const Icon(Icons.settings, color: Color(0xFF0F172A)),
      onTap: () => showDialog(context: context, builder: (c) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "YouTube Video ID")),
        actions: [
          ElevatedButton(onPressed: () { onSave(controller.text); Navigator.pop(c); }, child: const Text("ОК"))
        ],
      )),
    );
  }
}void showSafetyDialog(BuildContext context, VoidCallback onConfirm) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text("⚠️ БЕЗОПАСНОСТЬ"),
      content: const Text("Баллон находится под давлением 150 атм. Подтвердите, что вы ознакомлены с правилами эксплуатации редуктора."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")),
        ElevatedButton(onPressed: () { Navigator.pop(c); onConfirm(); }, child: const Text("Я СОГЛАСЕН")),
      ],
    ),
  );
}