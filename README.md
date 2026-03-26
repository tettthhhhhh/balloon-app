# INDGAS EXPRESS

Flutter-приложение для заказа гелия, шаров и оборудования с собственным backend на Express + MySQL, без Firebase phone auth.

## Что уже есть

- тёплый брендовый UI с анимациями для auth, каталога, помощника, корзины и checkout
- разделение аренды и продажи на уровне карточек, корзины и заказа
- клиентские, курьерские и админские сценарии
- локальный backend на Express + MySQL с миграциями и автосидом из legacy store
- demo checkout с безопасной маской карты вместо хранения сырых карточных данных

## Структура

```text
lib/
  app/
    app.dart
    app_controller.dart
    app_scope.dart
    models/
    screens/
    services/
    theme/
    widgets/

server/
  src/server.js
  data/store.json
  .env.example
```

## Локальный запуск backend

Перед первым запуском убедись, что локальный MySQL поднят и `server/.env` заполнен.

```powershell
cd C:\project\server
npm install
npm run db:setup
npm start
```

По умолчанию API поднимается на `http://localhost:8787/api`.

## Локальный запуск Flutter

```powershell
cd C:\project
flutter pub get
flutter run
```

Если `API_BASE_URL` не задан, приложение использует:

- `http://127.0.0.1:8787/api` на Windows, macOS и Linux
- `http://10.0.2.2:8787/api` на Android-эмуляторе
- `http://localhost:8787/api` в web

## Переключение на другой API

Для сборки или запуска с внешним сервером используй `dart-define`:

```powershell
flutter run --dart-define=API_BASE_URL=http://82.148.17.131:8787/api
```

Когда будешь готов переключиться на домен:

```powershell
flutter run --dart-define=API_BASE_URL=https://express.indgas.ru/api
```

## Переменные окружения backend

В `server/.env.example` лежат базовые настройки:

```text
PORT=8787
APP_SECRET=change-me-for-production
CORS_ORIGIN=http://localhost:3000,https://express.indgas.ru
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=indgas_dev
DB_USER=indgas
DB_PASSWORD=change-me-local
```

Сейчас сервер читает:

- `PORT`
- `APP_SECRET`
- `CORS_ORIGIN`
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

При старте backend:

- применяет SQL-миграции из `server/src/db/migrations`
- при пустой базе импортирует демо-данные из `server/data/store.json`
- поднимает тот же API-контракт, который использует Flutter-клиент

## Production deployment

В проекте уже лежат шаблоны для Linux:

- `deploy/linux/indgas-express-api.service`
- `deploy/linux/express.indgas.ru.nginx.conf`
- `deploy/linux/deploy-main.sh`
- `deploy/linux/post-receive`
- `deploy/windows/deploy-express.ps1`
- `deploy/windows/publish-main.ps1`

Текущая схема выкладки:

- Flutter web собирается с `--dart-define=API_BASE_URL=/api`
- `nginx` раздаёт `build/web`
- `nginx` проксирует `/api` на локальный Node backend
- backend работает как systemd-сервис `indgas-express-api.service`

Для повторной выкладки с Windows можно использовать:

```powershell
powershell -ExecutionPolicy Bypass -File C:\project\deploy\windows\deploy-express.ps1
```

## Stub checkout flow

Пока внешние сервисы не подключены, backend уже работает по правильной последовательности статусов:

- `awaiting_signature` после создания заказа
- `awaiting_payment` после stub-подписания договора
- `paid` после stub-подтверждения оплаты
- `active` после выдачи курьером
- `completed` после возврата возвратной тары

Для этого в MySQL уже есть отдельные таблицы:

- `contracts`
- `payments`
- `cylinder_logs`

Stub-маршруты для будущих интеграций:

- `POST /api/orders/:orderId/contracts/sign-stub`
- `POST /api/orders/:orderId/payments/confirm-stub`
- `POST /api/webhooks/stub/contracts/signed`
- `POST /api/webhooks/stub/payments/paid`

Webhook-маршруты защищаются через `APP_SECRET` в заголовке `x-stub-secret`.

Если нужно быстро вернуть локальную dev-базу к исходному demo-состоянию:

```powershell
cd C:\project\server
npm run reset
```

## Git auto-deploy flow

Если хочешь работать по схеме `dev -> main -> production`, логика такая:

- работаешь локально в `dev`
- проверяешь изменения у себя
- мержишь `dev` в `main`
- пушишь `main` в `origin`
- локально собираешь `build/web`
- пушишь `main` в `production`
- bare-репозиторий на сервере получает push в `main` и быстро обновляет только backend
- готовый `build/web` архивом загружается на сервер и публикуется без Flutter-сборки на VPS

Для упрощения этого сценария можно использовать:

```powershell
powershell -ExecutionPolicy Bypass -File C:\project\deploy\windows\publish-main.ps1
```

Этот скрипт:

- проверяет чистоту рабочего дерева
- запускает `flutter analyze`
- делает `fast-forward merge` из `dev` в `main`
- локально собирает `flutter build web --release --dart-define=API_BASE_URL=/api --no-wasm-dry-run`
- пушит `main` в `origin`
- пушит `main` в `production`
- загружает готовый web-бандл на сервер
- запускает `/opt/indgas-express/bin/deploy-main.sh --web-archive ...`

Почему так лучше:

- VPS больше не тратит 10+ минут на `flutter build web`
- production-обновления становятся заметно стабильнее на слабом сервере
- серверу не нужен Flutter SDK для обычного релиза фронта

## Demo-аккаунты

- `demo / demo12345`
- `courier / courier12345`
- `admin / admin12345`

## Важно про оплату

Checkout сейчас демонстрационный, но аккуратно спроектирован:

- номер карты форматируется и валидируется на клиенте
- CVV не уходит в backend
- backend получает только маску карты вроде `•••• 4242`

Для production-оплаты дальше нужно будет подключать провайдера с токенизацией или hosted checkout.
