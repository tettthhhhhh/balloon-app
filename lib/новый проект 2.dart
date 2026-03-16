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
      // Пока ставим заглушку, потом заменим на главный экран выбора ролей
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
List<GasCylinder> globalProducts = [
  GasCylinder(
    title: "Гелий 10Л (Коричневый)",
    shortDescription: "Аттестован. Гелий марки 'Б'.",
    fullDescription: "Идеально подходит для надувания до 100 шаров. Баллон под давлением 150 атм. Обязателен возврат тары.",
    priceInt: 3000,
    imageUrls: ["https://via.placeholder.com/150"], // Позже заменишь на свои ссылки
  ),
  GasCylinder(
    title: "Проф. редуктор",
    shortDescription: "С нажимным клапаном.",
    fullDescription: "Обеспечивает безопасное снижение давления со 150 атм до рабочего. Подходит для латексных и фольгированных шаров.",
    priceInt: 3500,
    imageUrls: ["https://via.placeholder.com/150"],
  ),
];

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
            ElevatedButton(
              onPressed: () {
                // Переход в приложение Клиента
              },
              child: const Text("Войти как КЛИЕНТ"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Переход в интерфейс Курьера
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Войти как КУРЬЕР"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Переход в Панель Админа
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