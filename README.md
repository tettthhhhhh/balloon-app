# INDGAS EXPRESS

Flutter-приложение для заказа гелия, шаров и оборудования с собственным backend без Firebase phone auth.

## Что уже есть

- тёплый брендовый UI с анимациями для auth, каталога, помощника, корзины и checkout
- разделение аренды и продажи на уровне карточек, корзины и заказа
- клиентские, курьерские и админские сценарии
- локальный backend на Node.js без внешних зависимостей
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

```powershell
cd C:\project\server
node src/server.js
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
CORS_ORIGIN=https://express.indgas.ru
```

Сейчас сервер читает:

- `PORT`
- `APP_SECRET`
- `CORS_ORIGIN`

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

## Git auto-deploy flow

Если хочешь работать по схеме `dev -> main -> production`, логика такая:

- работаешь локально в `dev`
- проверяешь изменения у себя
- мержишь `dev` в `main`
- пушишь `main` в `origin`
- пушишь `main` в `production`
- bare-репозиторий на сервере получает push в `main`, запускает `post-receive` и вызывает `deploy-main.sh`

Для упрощения этого сценария можно использовать:

```powershell
powershell -ExecutionPolicy Bypass -File C:\project\deploy\windows\publish-main.ps1
```

Этот скрипт:

- проверяет чистоту рабочего дерева
- запускает `flutter analyze`
- делает `fast-forward merge` из `dev` в `main`
- пушит `main` в `origin`
- пушит `main` в `production`

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
