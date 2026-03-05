import 'package:flutter/material.dart';

void main() {
  runApp(const GasExpressApp());
}

class GasExpressApp extends StatelessWidget {
  const GasExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GAS EXPRESS',
      theme: ThemeData(
        primaryColor: const Color(0xFF0F172A),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const RoleSelectionPage(), 
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================
// 1. МОДЕЛИ ДАННЫХ (Data Models)
// ==========================================

class GasCylinder {
  String title;
  String shortDescription;
  String fullDescription;
  int priceInt;
  List<String> imageUrls;

  GasCylinder({
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
  final String id;
  final String date;
  final int totalAmount;
  final int itemCount; // Количество баллонов для учета на складе
  final String customerName;
  final String location;
  final String qrCode;
  final String contractText;
  String status; // "Оплачен", "Активен", "Завершен"

  Order({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.itemCount,
    required this.customerName,
    required this.location,
    required this.qrCode,
    required this.contractText,
    this.status = "Оплачен", // Статус по умолчанию при создании
  });
}

// ==========================================
// 2. ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ (State Management MVP)
// ==========================================

// Склад
int totalCylindersInStock = 50; 

// Текущий пользователь (заглушка для Личного кабинета)
String currentUserName = "Иван Иванов";
String selectedLocation = "Склад на Ленина, 15";

// Настройки контента
String promoVideoId = "dQw4w9WgXcQ"; // Заглушка YouTube ID
String safetyVideoId = "dQw4w9WgXcQ";

// Корзина и История заказов
List<CartItem> cart = [];
List<Order> orderHistory = [];

// Каталог товаров
// Каталог товаров
List<GasCylinder> globalProducts = [
  GasCylinder(
    title: "Гелий 10Л (Коричневый)",
    shortDescription: "Аттестован. Гелий марки 'Б'.",
    fullDescription: "Идеально подходит для надувания до 100 шаров. Баллон под давлением 150 атм. Обязателен возврат тары.",
    priceInt: 3000,
    imageUrls: ["https://via.placeholder.com/150"], 
  ),
  GasCylinder(
    title: "Проф. редуктор",
    shortDescription: "С нажимным клапаном.",
    fullDescription: "Обеспечивает безопасное снижение давления со 150 атм до рабочего. Подходит для латексных и фольгированных шаров.",
    priceInt: 3500,
    imageUrls: ["https://via.placeholder.com/150"],
  ),
  // Вернули потерянный товар!
  GasCylinder(
    title: "Набор 'Праздник'",
    shortDescription: "Баллон 10Л + Редуктор + Шары",
    fullDescription: "Готовый комплект для мероприятия. Включает полный 10-литровый баллон гелия, профессиональный редуктор и упаковку латексных шаров.",
    priceInt: 5500,
    imageUrls: ["https://via.placeholder.com/150"],
  ),
];

// ==========================================
// 3. СТРАНИЦА ВЫБОРА РОЛЕЙ (Навигация)
// ==========================================

// ==========================================
// 3. СТРАНИЦА ВЫБОРА РОЛЕЙ (Навигация)
// ==========================================

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GAS EXPRESS - Выбор роли")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- ВОТ ТА САМАЯ КНОПКА КЛИЕНТА ---
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const ClientHomePage())
                );
              },
              child: const Text("Войти как КЛИЕНТ"),
            ),
            
            const SizedBox(height: 20),
            
           ElevatedButton(
              onPressed: () {
                // Переход в интерфейс Курьера
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const CourierPage())
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Войти как КУРЬЕР"),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () {
                // Переход в Панель Админа
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AdminPanelPage())
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Войти как АДМИН"),
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// 4. МОДУЛЬ КЛИЕНТА (Витрина и Корзина)
// ==========================================

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  // Умное добавление в корзину (группировка позиций)
  void addToCart(GasCylinder product) {
    setState(() {
      int index = cart.indexWhere((item) => item.product.title == product.title);
      if (index != -1) {
        cart[index].quantity += 1; // Увеличиваем количество, если уже есть
      } else {
        cart.add(CartItem(product: product, quantity: 1)); // Добавляем новый
      }
    });

    // Тот самый правильный "плавающий" SnackBar
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${product.title} добавлен!"),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(milliseconds: 800),
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Считаем общее количество товаров для значка на корзине
    int totalItems = cart.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text("GAS EXPRESS"),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // Переход в корзину
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())).then((_) => setState(() {}));
                },
              ),
              if (totalItems > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$totalItems', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: globalProducts.length,
        itemBuilder: (context, index) {
          final product = globalProducts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заглушка для картинки
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(product.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(product.shortDescription, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${product.priceInt} ₽", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => addToCart(product),
                        child: const Text("В корзину"),
                      )
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 5. КОРЗИНА И ТЕХНИКА БЕЗОПАСНОСТИ
// ==========================================

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // 1. ДИАЛОГ ТЕХНИКИ БЕЗОПАСНОСТИ
  void _showSafetyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30), SizedBox(width: 10), Text("ВНИМАНИЕ!")],
        ),
        content: const Text(
          "Баллоны находятся под высоким давлением (150 атм).\n\n"
          "1. Использование неисправного редуктора строго запрещено!\n"
          "2. Баллон должен быть надежно закреплен.\n\n"
          "Подтвердите, что вы ознакомлены с правилами техники безопасности.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог ТБ
              _showSignatureDialog(); // Открываем виджет ЭЦП!
            },
            child: const Text("СОГЛАСЕН"),
          ),
        ],
      ),
    );
  }

  // 2. ВИДЖЕТ ЭЛЕКТРОННОЙ ПОДПИСИ (ЭЦП / ПЭП)
  void _showSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Подписание договора"),
        content: Column(
          mainAxisSize: MainAxisSize.min, // Чтобы окно не растягивалось на весь экран
          children: [
            const Text(
              "Для аренды возвратной тары необходимо подписать договор простой электронной подписью (ПЭП).",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Заглушка PDF-договора
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text("Договор_аренды_оборудования.pdf", style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Поле ввода SMS-кода
            const TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: "Введите SMS-код",
                hintText: "Например: 1234",
                border: OutlineInputBorder(),
                counterText: "", // Скрываем счетчик символов
                prefixIcon: Icon(Icons.message),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Закрываем окно ЭЦП

              // --- ЛОГИКА ОПЛАТЫ И СПИСАНИЯ СО СКЛАДА ---
              setState(() {
                int totalAmount = cart.fold(0, (sum, item) => sum + (item.product.priceInt * item.quantity));
                int totalItems = cart.fold(0, (sum, item) => sum + item.quantity);
                String newOrderId = "${100 + orderHistory.length}"; 

                orderHistory.add(Order(
                  id: newOrderId,
                  date: "Сегодня",
                  totalAmount: totalAmount,
                  itemCount: totalItems,
                  customerName: currentUserName,
                  location: selectedLocation,
                  qrCode: "QR_$newOrderId",
                  contractText: "Подписан ПЭП (SMS-код)", // Зафиксировали подписание
                  status: "Оплачен" 
                ));

                totalCylindersInStock -= totalItems; // Минусуем склад
                cart.clear(); // Очищаем корзину
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Договор подписан! Заказ передан курьеру."), 
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                )
              );
            },
            child: const Text("ПОДПИСАТЬ И ОПЛАТИТЬ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = cart.fold(0, (sum, item) => sum + (item.product.priceInt * item.quantity));

    return Scaffold(
      appBar: AppBar(title: const Text("Корзина")),
      body: cart.isEmpty
          ? const Center(child: Text("Ваша корзина пуста", style: TextStyle(fontSize: 18, color: Colors.grey)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item.product.priceInt} ₽  x  ${item.quantity} шт."),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  setState(() {
                                    if (item.quantity > 1) {
                                      item.quantity--;
                                    } else {
                                      cart.removeAt(index);
                                    }
                                  });
                                },
                              ),
                              Text("${item.quantity}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() => item.quantity++),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Итого:", style: TextStyle(fontSize: 20, color: Colors.grey)),
                          Text("$totalAmount ₽", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                          onPressed: _showSafetyDialog, // Вызов диалога безопасности перед оплатой
                          child: const Text("ОФОРМИТЬ ЗАКАЗ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}// ==========================================
// 6. МОДУЛЬ КУРЬЕРА (Склад и Выдача)
// ==========================================

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
      // Убираем лишние знаки, чтобы курьер мог ввести просто "690" или "№690"
      String query = _searchController.text.trim().replaceAll("№", ""); 
      try {
        _foundOrder = orderHistory.firstWhere(
          (o) => o.id.replaceAll("№", "") == query
        );
      } catch (e) {
        _foundOrder = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Заказ не найден. Проверьте номер."))
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Выдача оборудования"),
        backgroundColor: Colors.orange.shade800, // Отличаем интерфейс курьера цветом
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Поле поиска заказа
            TextField(
              controller: _searchController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Введите ID заказа (например: 690)",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.orange), 
                  onPressed: _findOrder
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange.shade800, width: 2),
                  borderRadius: BorderRadius.circular(12)
                ),
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
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Заказ ${_foundOrder!.id}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _foundOrder!.status == "Оплачен" ? Colors.orange.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text(
                            _foundOrder!.status,
                            style: TextStyle(
                              color: _foundOrder!.status == "Оплачен" ? Colors.orange.shade800 : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    const Divider(height: 30),
                    Text("Клиент: ${_foundOrder!.customerName}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text("К выдаче: ${_foundOrder!.itemCount} шт.", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // --- ЛОГИКА ВЫДАЧИ ---
                    if (_foundOrder!.status == "Оплачен") ...[
                      const Text("Для подтверждения введите номер баллона:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bottleIdController,
                        decoration: const InputDecoration(
                          hintText: "Например: ГЛ-10-690",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A), 
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () {
                            if (_bottleIdController.text.trim().isNotEmpty) {
                              setState(() {
                                // ПЕРЕВОДИМ СТАТУС В АКТИВЕН
                                _foundOrder!.status = "Активен";
                              });
                              _bottleIdController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("✅ Заказ успешно выдан!"), backgroundColor: Colors.green)
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Ошибка: обязательно введите номер тары!"), backgroundColor: Colors.red)
                              );
                            }
                          },
                          child: const Text("ВЫДАТЬ ОБОРУДОВАНИЕ", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else if (_foundOrder!.status == "Активен") ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text("Оборудование уже у клиента", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
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
}// ==========================================
// 7. ПАНЕЛЬ АДМИНИСТРАТОРА (Дашборд и Учет)
// ==========================================

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});
  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  @override
  Widget build(BuildContext context) {
    // Расчет общей выручки из истории заказов (только не отмененные)
    int totalSales = orderHistory.where((o) => o.status != "Ожидает").fold(0, (sum, item) => sum + item.totalAmount);

    // Считаем количество баллонов, которые оплачены, но еще не выданы курьером
    int awaitingCylinders = orderHistory.where((o) => o.status == "Оплачен").fold(0, (sum, o) => sum + o.itemCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("ПАНЕЛЬ УПРАВЛЕНИЯ"),
        backgroundColor: const Color(0xFF0F172A), 
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- БЛОК 1: СТАТИСТИКА ПРОДАЖ ---
          _buildSectionTitle("Контроль продаж"),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), 
              borderRadius: BorderRadius.circular(20)
            ),
            child: Column(
              children: [
                _statusRow("Всего заказов:", "${orderHistory.length}"),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Общая выручка:", "$totalSales ₽"),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Баллонов на складе:", "$totalCylindersInStock шт."),
                const Divider(color: Colors.white24, height: 30),
                _statusRow("Ожидают выдачи:", "$awaitingCylinders шт."),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- БЛОК 2: ТАБЛИЦА АКТИВНЫХ АРЕНД ---
          _buildSectionTitle("Текущие операции (10л баллоны)"),
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
                    DataCell(Text(
                      order.status, 
                      style: TextStyle(
                        color: order.status == "Оплачен" ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold
                      )
                    )),
                    DataCell(
                      order.status == "Активен" 
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                          onPressed: () {
                            setState(() {
                              order.status = "Завершен";
                              // Возврат всей партии на склад
                              totalCylindersInStock += order.itemCount; 
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Вернулось баллонов: ${order.itemCount} шт."))
                            );
                          },
                          child: const Text("Принять"),
                        )
                      : const Text("Ждёт выдачи", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // --- БЛОК 3: РЕДАКТОР КАТАЛОГА ---
          _buildSectionTitle("Редактор каталога товаров"),
          ...globalProducts.map((p) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: const Color(0xFFF8FAFC),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12)
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                child: const Icon(Icons.image, color: Colors.grey),
              ),
              title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${p.priceInt} ₽"),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                onPressed: () => _editProduct(p),
              ),
            ),
          )).toList(),

          const SizedBox(height: 32),

          // --- БЛОК 4: УПРАВЛЕНИЕ ВИДЕО ---
          _buildSectionTitle("Настройка видео-контента"),
          _videoEditTile("Промо-ролик", promoVideoId, (val) => setState(() => promoVideoId = val)),
          _videoEditTile("Инструкция редуктора", safetyVideoId, (val) => setState(() => safetyVideoId = val)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ (Внутри _AdminPanelPageState) ---

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
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
      child: ListTile(
        title: Text(label),
        subtitle: Text("ID: $currentId"),
        trailing: const Icon(Icons.settings, color: Color(0xFF0F172A)),
        onTap: () => showDialog(context: context, builder: (c) => AlertDialog(
          title: Text(label),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: "YouTube Video ID")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Отмена")),
            ElevatedButton(onPressed: () { onSave(controller.text); Navigator.pop(c); }, child: const Text("ОК"))
          ],
        )),
      ),
    );
  }
}