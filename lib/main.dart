import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// -------------------- ГЛОБАЛЬНЫЕ ДАННЫЕ --------------------
int totalCylindersInStock = 20;
List<CartItem> cart = [];
List<Order> orderHistory = [];
bool isLoggedIn = false;
String currentUserName = "Иван Иванов";
String currentUserEmail = "ivan@gas.ru";
String selectedLocation = "Центральный склад";

String promoVideoId = "OjxoHgnaNL8";
String safetyVideoId = "OjxoHgnaNL8";

// ДОБАВЛЕНО: Уникальный ID для каждого товара
class GasCylinder {
  final String id, title, shortDescription, fullDescription;
  int priceInt; // Убрали final, чтобы легко менять цену в админке
  final List<String> imageUrls;

  GasCylinder({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.priceInt,
    required this.imageUrls,
  });
}

class CartItem {
  final GasCylinder product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class Order {
  final String id, date, customerName, location, qrCode, contractText;
  final int totalAmount, itemCount;
  String status;

  Order({
    required this.id, required this.date, required this.totalAmount, required this.itemCount,
    required this.customerName, required this.location, required this.qrCode, required this.contractText,
    this.status = "Оплачен",
  });
}

List<GasCylinder> globalProducts = [
  GasCylinder(
    id: "prod_1",
    title: "Гелий 10Л (Коричневый)",
    shortDescription: "Аттестован. Гелий марки 'Б'.",
    fullDescription: "Стальной баллон 10 литров. ГОСТ 949-73. Идеален для надувания до 100 шаров. Возврат тары обязателен.",
    priceInt: 3000,
    imageUrls: ["https://i.postimg.cc/KjRcWtLM/19e10b22-12e6-464b-950b-84ace40f032e.png"],
  ),
  GasCylinder(
    id: "prod_2",
    title: "Проф. редуктор",
    shortDescription: "С нажимным клапаном.",
    fullDescription: "Обеспечивает мягкую подачу газа. Манометр для контроля давления. Экономия гелия до 20%.",
    priceInt: 3500,
    imageUrls: ["https://i.postimg.cc/wvWTFwtj/83c127b5-e691-4d52-8f52-b17e86461725.png"],
  ),
];

void main() => runApp(const GasRentApp());

// -------------------- APP --------------------
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A), secondary: const Color(0xFFF59E0B)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F172A), foregroundColor: Colors.white, centerTitle: true),
      ),
      home: const RoleSelectionPage(),
    );
  }
}

// -------------------- ВЫБОР РОЛЕЙ --------------------
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.gas_meter, size: 80, color: Color(0xFF0F172A)),
          const SizedBox(height: 20),
          const Text("GAS EXPRESS PRO", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 40),
          _roleBtn(context, "ВОЙТИ КАК КЛИЕНТ", Colors.blue, const HomePage()),
          const SizedBox(height: 16),
          _roleBtn(context, "РЕЖИМ КУРЬЕРА", Colors.orange, const CourierPage()),
          const SizedBox(height: 16),
          _roleBtn(context, "АДМИН-ПАНЕЛЬ", Colors.red, const AdminPanelPage()),
        ]),
      ),
    );
  }

  Widget _roleBtn(ctx, txt, clr, page) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: clr, foregroundColor: Colors.white, minimumSize: const Size(280, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => page)),
    child: Text(txt, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}

// -------------------- HOME (КЛИЕНТ) --------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GAS EXPRESS"),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) => setState(() {}))),
        ],
      ),
      body: [_buildStore(), const AssistantPage(), const CartPage()][_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: "Маркет"),
          NavigationDestination(icon: Icon(Icons.lightbulb), label: "Помощник"),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: "Корзина"),
        ],
      ),
    );
  }

  Widget _buildStore() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoId: promoVideoId))),
          child: Container(
            height: 180,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: const DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1530103862676-de8c9debad1d?q=80&w=1000"), fit: BoxFit.cover)),
            child: Center(child: Icon(Icons.play_circle_fill, size: 60, color: Colors.white.withOpacity(0.9))),
          ),
        ),
        const SizedBox(height: 24),
        const Text("Каталог оборудования", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...globalProducts.map((p) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: Image.network(p.imageUrls[0], width: 50),
            title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${p.priceInt} ₽"),
            trailing: IconButton(icon: const Icon(Icons.add_shopping_cart, color: Colors.blue), onPressed: () {
              setState(() {
                // ИСПРАВЛЕНО: Ищем по уникальному ID, а не по названию
                final index = cart.indexWhere((item) => item.product.id == p.id);
                if (index != -1) {
                  cart[index].quantity++;
                } else {
                  cart.add(CartItem(product: p));
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Добавлено в корзину!")));
            }),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p))).then((_) => setState((){})),
          ),
        )),
      ],
    );
  }
}

// -------------------- ПОМОЩНИК (КАЛЬКУЛЯТОР) --------------------
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});
  @override State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  double _balloons = 50;
  String _type = 'Standard';
  final Map<String, double> _cons = {'Mini': 8.0, 'Standard': 14.0, 'Foil': 16.0};

  @override
  Widget build(BuildContext context) {
    int cylinders = ((_balloons * _cons[_type]!) / 1500).ceil();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Центр управления", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
          child: Column(children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'Mini', label: Text("10\"")), ButtonSegment(value: 'Standard', label: Text("12\"")), ButtonSegment(value: 'Foil', label: Text("18\""))],
              selected: {_type}, onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Количество:"), Text("${_balloons.toInt()} шт.", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
            Slider(value: _balloons, min: 5, max: 500, activeColor: Colors.orange, onChanged: (v) => setState(() => _balloons = v)),
            const Divider(height: 40),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Нужно баллонов (10л):", style: TextStyle(fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)), child: Text("$cylinders шт.", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ]),
          ]),
        ),
        const SizedBox(height: 30),
        _infoCard("Защита оборудования", Icons.shield_outlined, ["• Всегда накручивайте колпак.", "• Оставляйте давление 0.5 атм."]),
      ]),
    );
  }
  Widget _infoCard(t, i, lines) => Card(margin: const EdgeInsets.only(bottom: 16), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(i, color: Colors.orange), const SizedBox(width: 10), Text(t, style: const TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 10), ...lines.map((l) => Text(l)).toList()])));
}

// -------------------- КОРЗИНА И ОПЛАТА --------------------
class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    int total = cart.fold(0, (s, i) => s + (i.product.priceInt * i.quantity));
    return Scaffold(
      body: cart.isEmpty ? const Center(child: Text("Пусто")) : Column(children: [
        Expanded(child: ListView.builder(itemCount: cart.length, itemBuilder: (c, i) => ListTile(
          title: Text(cart[i].product.title), 
          subtitle: Text("${cart[i].product.priceInt} ₽"),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => cart[i].quantity > 1 ? cart[i].quantity-- : cart.removeAt(i))),
            Text("${cart[i].quantity}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => cart[i].quantity++)),
          ]),
        ))),
        Padding(padding: const EdgeInsets.all(24), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)), onPressed: () => _processOrder(total), child: Text("Оформить за $total ₽")))
      ]),
    );
  }

  void _processOrder(int total) {
    showSafetyDialog(context, () {
      setState(() {
        int count = cart.fold(0, (s, i) => s + i.quantity);
        // ИСПРАВЛЕНО: Уникальный ID на основе времени, исключающий коллизии
        String safeOrderId = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
        
        orderHistory.insert(0, Order(id: safeOrderId, date: "Сегодня", totalAmount: total, itemCount: count, customerName: currentUserName, location: selectedLocation, qrCode: "QR", contractText: "Подписано ПЭП"));
        totalCylindersInStock -= count;
        cart.clear();
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SuccessPage()));
    });
  }
}

// -------------------- СТРАНИЦА КУРЬЕРА --------------------
class CourierPage extends StatefulWidget {
  const CourierPage({super.key});
  @override State<CourierPage> createState() => _CourierPageState();
}

class _CourierPageState extends State<CourierPage> {
  final _searchCtrl = TextEditingController();
  final _bottleCtrl = TextEditingController();
  Order? _found;

  // ИСПРАВЛЕНО: Уничтожаем контроллеры для избежания Memory Leaks
  @override
  void dispose() {
    _searchCtrl.dispose();
    _bottleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Выдача (Курьер)"), backgroundColor: Colors.orange),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        TextField(controller: _searchCtrl, decoration: const InputDecoration(labelText: "Введите ID заказа", suffixIcon: Icon(Icons.search)), keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () {
          setState(() {
            try { 
              // ИСПРАВЛЕНО: Чистый поиск без костылей с "№"
              _found = orderHistory.firstWhere((o) => o.id == _searchCtrl.text.trim()); 
            } 
            catch(e) { _found = null; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Заказ не найден"))); }
          });
        }, child: const Text("НАЙТИ ЗАКАЗ")),
        if (_found != null) ...[
          const SizedBox(height: 30),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Заказ №${_found!.id}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Клиент: ${_found!.customerName}"),
            Text("Количество: ${_found!.itemCount} шт."),
            const Divider(),
            if (_found!.status == "Оплачен") ...[
              const Text("Введите номер баллона для выдачи:"),
              TextField(controller: _bottleCtrl, decoration: const InputDecoration(hintText: "ГЛ-10-...")),
              const SizedBox(height: 20),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () {
                if (_bottleCtrl.text.isNotEmpty) {
                  setState(() => _found!.status = "Активен");
                  _bottleCtrl.clear();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ЗАКАЗ ВЫДАН!")));
                }
              }, child: const Text("ПОДТВЕРДИТЬ ВЫДАЧУ"))
            ] else Center(child: Text("СТАТУС: ${_found!.status}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
          ])))
        ]
      ])),
    );
  }
}

// -------------------- АДМИН-ПАНЕЛЬ --------------------
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});
  @override State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  @override
  Widget build(BuildContext context) {
    // ИСПРАВЛЕНО: Считаем выручку корректно, суммируя все заказы в истории
    int rev = orderHistory.fold(0, (s, o) => s + o.totalAmount);
    int activeCount = orderHistory.where((o) => o.status == "Активен").fold(0, (s, o) => s + o.itemCount);

    return Scaffold(
      appBar: AppBar(title: const Text("Админка"), backgroundColor: Colors.red),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(color: const Color(0xFF0F172A), child: ListTile(title: const Text("Выручка", style: TextStyle(color: Colors.white)), trailing: Text("$rev ₽", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        Card(color: const Color(0xFF0F172A), child: ListTile(title: const Text("Склад (свободно)", style: TextStyle(color: Colors.white)), trailing: Text("$totalCylindersInStock шт.", style: const TextStyle(color: Colors.white)))),
        Card(color: const Color(0xFF0F172A), child: ListTile(title: const Text("Баллонов у клиентов", style: TextStyle(color: Colors.white)), trailing: Text("$activeCount шт.", style: const TextStyle(color: Colors.white)))),
        const SizedBox(height: 30),
        const Text("Редактор цен:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...globalProducts.map((p) => ListTile(title: Text(p.title), subtitle: Text("${p.priceInt} ₽"), trailing: const Icon(Icons.edit), onTap: () {
          final c = TextEditingController(text: p.priceInt.toString());
          showDialog(context: context, builder: (ctx) => AlertDialog(content: TextField(controller: c, keyboardType: TextInputType.number), actions: [
            ElevatedButton(onPressed: () { 
              // ИСПРАВЛЕНО: Мутируем напрямую поле цены, а не пересоздаем объект
              setState(() { p.priceInt = int.parse(c.text); }); 
              Navigator.pop(ctx); 
            }, child: const Text("ОК"))
          ]));
        })).toList(),
        const Divider(),
        const Text("Настройка видео:", style: TextStyle(fontWeight: FontWeight.bold)),
        _videoEditTile("Промо-ролик", promoVideoId, (val) => setState(() => promoVideoId = val)),
        _videoEditTile("Инструкция редуктора", safetyVideoId, (val) => setState(() => safetyVideoId = val)),
        const Divider(),
        const Text("Активные аренды:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...orderHistory.where((o) => o.status == "Активен").map((o) => ListTile(
          title: Text(o.customerName),
          subtitle: Text("Заказ №${o.id}"),
          trailing: ElevatedButton(onPressed: () => setState(() { o.status = "Завершен"; totalCylindersInStock += o.itemCount; }), child: const Text("Принять")),
        )),
      ]),
    );
  }

  // ИСПРАВЛЕНО: Контроллер создается только при клике и очищается из памяти
  Widget _videoEditTile(String label, String currentId, Function(String) onSave) {
    return ListTile(
      title: Text(label),
      subtitle: Text("ID: $currentId"),
      trailing: const Icon(Icons.settings),
      onTap: () {
        final controller = TextEditingController(text: currentId);
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(label),
            content: TextField(controller: controller, decoration: const InputDecoration(labelText: "YouTube Video ID")),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("Отмена")),
              ElevatedButton(
                onPressed: () { onSave(controller.text); Navigator.pop(c); },
                child: const Text("ОК")
              )
            ],
          ),
        ).then((_) => controller.dispose());
      },
    );
  }
}

// -------------------- ВСПОМОГАТЕЛЬНЫЕ ЭКРАНЫ --------------------
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, size: 100, color: Colors.green), const Text("УСПЕХ!"), ElevatedButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionPage()), (r) => false), child: const Text("В НАЧАЛО"))])));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Профиль")), body: ListView(padding: const EdgeInsets.all(20), children: [ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(currentUserName), subtitle: Text(currentUserEmail))]));
}

class ProductDetailsPage extends StatefulWidget {
  final GasCylinder product;
  const ProductDetailsPage({required this.product, super.key});
  @override State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.product.title)), body: ListView(children: [Image.network(widget.product.imageUrls.first), Padding(padding: const EdgeInsets.all(20), child: Text(widget.product.fullDescription)), Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(onPressed: () { setState(() { final idx = cart.indexWhere((i) => i.product.id == widget.product.id); if (idx != -1) cart[idx].quantity++; else cart.add(CartItem(product: widget.product)); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Добавлено!"))); }, child: const Text("В корзину")))]));
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  const VideoPlayerScreen({super.key, required this.videoId});
  @override State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _ctrl;
  @override void initState() { super.initState(); _ctrl = YoutubePlayerController.fromVideoId(videoId: widget.videoId, autoPlay: true, params: const YoutubePlayerParams(showFullscreenButton: true)); }
  @override void dispose() { _ctrl.close(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white), body: Center(child: YoutubePlayer(controller: _ctrl)));
}

void showSafetyDialog(BuildContext context, VoidCallback onConfirm) {
  showDialog(context: context, builder: (c) => AlertDialog(title: const Text("⚠️ БЕЗОПАСНОСТЬ"), content: const Text("Баллон 150 атм. Подтвердите знание правил эксплуатации."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")), ElevatedButton(onPressed: () { Navigator.pop(c); onConfirm(); }, child: const Text("Я СОГЛАСЕН"))]));
}