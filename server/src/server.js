const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const path = require('path');

const PORT = Number(process.env.PORT || 8787);
const TOKEN_SECRET = process.env.APP_SECRET || 'gas-express-dev-secret';
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';
const DATA_DIR = path.join(__dirname, '..', 'data');
const DATA_FILE = path.join(DATA_DIR, 'store.json');

bootstrapStore();

const server = http.createServer(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, 'http://localhost');
  const pathname = url.pathname;

  try {
    const store = readStore();
    const currentUser = getCurrentUser(req, store);

    if (
      (req.method === 'GET' || req.method === 'HEAD') &&
      pathname === '/api/health'
    ) {
      return json(res, 200, { ok: true });
    }

    if (req.method === 'GET' && pathname === '/api/config') {
      return json(res, 200, { config: store.config });
    }

    if (req.method === 'PATCH' && pathname === '/api/config') {
      ensureRole(currentUser, ['admin']);
      const body = await parseJson(req);
      store.config = {
        ...store.config,
        promoVideoId: String(body.promoVideoId || store.config.promoVideoId),
        safetyVideoId: String(body.safetyVideoId || store.config.safetyVideoId),
        supportPhone: String(body.supportPhone || store.config.supportPhone),
        brandMessage: String(body.brandMessage || store.config.brandMessage),
      };
      writeStore(store);
      return json(res, 200, { config: store.config });
    }

    if (req.method === 'POST' && pathname === '/api/auth/register') {
      const body = await parseJson(req);
      const login = String(body.login || '').trim().toLowerCase();
      const password = String(body.password || '');
      const fullName = String(body.fullName || '').trim();
      const phone = String(body.phone || '').trim();

      if (login.length < 3) {
        throw httpError(400, 'Логин должен быть не короче 3 символов.');
      }
      if (password.length < 6) {
        throw httpError(400, 'Пароль должен быть не короче 6 символов.');
      }
      if (fullName.length < 3) {
        throw httpError(400, 'Укажите имя пользователя.');
      }
      if (store.users.some((user) => user.login === login)) {
        throw httpError(409, 'Такой логин уже занят.');
      }

      const user = createUser({
        id: crypto.randomUUID(),
        login,
        password,
        fullName,
        phone,
        role: 'client',
      });

      store.users.unshift(user);
      writeStore(store);

      return json(res, 201, {
        token: signToken(user),
        user: sanitizeUser(user),
      });
    }

    if (req.method === 'POST' && pathname === '/api/auth/login') {
      const body = await parseJson(req);
      const login = String(body.login || '').trim().toLowerCase();
      const password = String(body.password || '');
      const user = store.users.find((item) => item.login === login);

      if (!user || !verifyPassword(password, user.passwordHash)) {
        throw httpError(401, 'Неверный логин или пароль.');
      }

      return json(res, 200, {
        token: signToken(user),
        user: sanitizeUser(user),
      });
    }

    if (req.method === 'GET' && pathname === '/api/products') {
      return json(res, 200, { products: store.products });
    }

    if (req.method === 'PATCH' && pathname.startsWith('/api/products/')) {
      ensureRole(currentUser, ['admin']);
      const productId = pathname.split('/').pop();
      const body = await parseJson(req);
      const product = store.products.find((item) => item.id === productId);

      if (!product) {
        throw httpError(404, 'Товар не найден.');
      }

      if (typeof body.title === 'string' && body.title.trim()) {
        product.title = body.title.trim();
      }
      if (typeof body.subtitle === 'string') {
        product.subtitle = body.subtitle.trim();
      }
      if (Number.isInteger(body.price) && body.price >= 0) {
        product.price = body.price;
      }
      if (Number.isInteger(body.stock) && body.stock >= 0) {
        product.stock = body.stock;
      }
      if (typeof body.unitLabel === 'string' && body.unitLabel.trim()) {
        product.unitLabel = body.unitLabel.trim();
      }
      if (typeof body.requiresReturn === 'boolean') {
        product.requiresReturn = body.requiresReturn;
      }
      if (typeof body.featured === 'boolean') {
        product.featured = body.featured;
      }

      writeStore(store);
      return json(res, 200, { product });
    }

    if (req.method === 'GET' && pathname === '/api/orders') {
      ensureAuthenticated(currentUser);

      let orders = [];
      if (currentUser.role === 'admin') {
        orders = store.orders;
      } else if (currentUser.role === 'courier') {
        orders = store.orders.filter(
          (order) => order.status === 'paid' || order.status === 'active',
        );
      } else {
        orders = store.orders.filter((order) => order.userId === currentUser.id);
      }

      orders = [...orders].sort(
        (left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt),
      );

      return json(res, 200, { orders });
    }

    if (req.method === 'POST' && pathname === '/api/orders') {
      ensureAuthenticated(currentUser);
      const body = await parseJson(req);
      const deliveryType = body.deliveryType === 'delivery' ? 'delivery' : 'pickup';
      const location = String(body.location || '').trim();
      const paymentMethod = String(body.paymentMethod || 'card_demo');
      const paymentMask = String(body.paymentMask || '').trim();
      const items = Array.isArray(body.items) ? body.items : [];

      if (!location) {
        throw httpError(400, 'Нужно указать точку получения или адрес.');
      }
      if (items.length === 0) {
        throw httpError(400, 'Корзина не должна быть пустой.');
      }

      const orderLines = [];
      let totalAmount = 0;

      for (const requestItem of items) {
        const product = store.products.find(
          (item) => item.id === requestItem.productId,
        );
        const quantity = Number(requestItem.quantity || 0);

        if (!product) {
          throw httpError(404, 'Один из товаров не найден.');
        }
        if (!Number.isInteger(quantity) || quantity <= 0) {
          throw httpError(400, 'Некорректное количество товара.');
        }
        if (product.stock < quantity) {
          throw httpError(
            409,
            `Недостаточно товара на складе: ${product.title}.`,
          );
        }

        product.stock -= quantity;
        totalAmount += product.price * quantity;
        orderLines.push({
          productId: product.id,
          title: product.title,
          quantity,
          unitPrice: product.price,
          requiresReturn: product.requiresReturn,
        });
      }

      const order = {
        id: crypto.randomUUID(),
        orderCode: nextOrderCode(store.orders.length + 1),
        userId: currentUser.id,
        customerName: currentUser.fullName,
        customerPhone: currentUser.phone,
        deliveryType,
        location,
        paymentMethod,
        paymentMask,
        status: 'paid',
        totalAmount,
        createdAt: new Date().toISOString(),
        items: orderLines,
        cylinderSerial: null,
        issuedAt: null,
        returnedAt: null,
      };

      store.orders.unshift(order);
      writeStore(store);

      return json(res, 201, { order });
    }

    if (req.method === 'POST' && pathname.endsWith('/issue')) {
      ensureRole(currentUser, ['courier', 'admin']);
      const orderId = pathname.split('/')[3];
      const body = await parseJson(req);
      const order = store.orders.find((item) => item.id === orderId);

      if (!order) {
        throw httpError(404, 'Заказ не найден.');
      }
      if (order.status !== 'paid') {
        throw httpError(409, 'Выдать можно только оплаченный заказ.');
      }

      order.status = 'active';
      order.cylinderSerial = String(body.cylinderSerial || '').trim();
      order.issuedAt = new Date().toISOString();

      writeStore(store);
      return json(res, 200, { order });
    }

    if (req.method === 'POST' && pathname.endsWith('/complete')) {
      ensureRole(currentUser, ['courier', 'admin']);
      const orderId = pathname.split('/')[3];
      const order = store.orders.find((item) => item.id === orderId);

      if (!order) {
        throw httpError(404, 'Заказ не найден.');
      }
      if (order.status !== 'active') {
        throw httpError(409, 'Завершить можно только активный заказ.');
      }

      for (const line of order.items) {
        if (!line.requiresReturn) continue;
        const product = store.products.find((item) => item.id === line.productId);
        if (product) {
          product.stock += line.quantity;
        }
      }

      order.status = 'completed';
      order.returnedAt = new Date().toISOString();

      writeStore(store);
      return json(res, 200, { order });
    }

    if (req.method === 'GET' && pathname === '/api/dashboard') {
      ensureRole(currentUser, ['admin']);
      const totalRevenue = store.orders.reduce(
        (sum, order) => sum + order.totalAmount,
        0,
      );
      const waitingOrders = store.orders.filter(
        (order) => order.status === 'paid',
      ).length;
      const activeOrders = store.orders.filter(
        (order) => order.status === 'active',
      ).length;
      const lowStockProducts = store.products.filter(
        (product) => product.stock <= 2,
      ).length;

      return json(res, 200, {
        stats: {
          totalRevenue,
          waitingOrders,
          activeOrders,
          lowStockProducts,
        },
      });
    }

    return json(res, 404, { message: 'Маршрут не найден.' });
  } catch (error) {
    const statusCode = error.statusCode || 500;
    return json(res, statusCode, {
      message: error.message || 'Внутренняя ошибка сервера.',
    });
  }
});

server.listen(PORT, () => {
  console.log(`IndGas Express API is running on http://localhost:${PORT}/api`);
});

function bootstrapStore() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(DATA_FILE)) {
    writeStore(createSeedStore());
  }
}

function readStore() {
  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
}

function writeStore(store) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(store, null, 2));
}

function createSeedStore() {
  return {
    config: {
      promoVideoId: 'OjxoHgnaNL8',
      safetyVideoId: 'OjxoHgnaNL8',
      supportPhone: '+7 (999) 555-40-40',
      brandMessage:
        'Быстрый заказ гелия, шаров и оборудования для праздников, фотозон и выездных оформлений.',
    },
    users: [
      createUser({
        id: crypto.randomUUID(),
        login: 'admin',
        password: 'admin12345',
        fullName: 'System Admin',
        phone: '+7 (999) 000-00-01',
        role: 'admin',
      }),
      createUser({
        id: crypto.randomUUID(),
        login: 'courier',
        password: 'courier12345',
        fullName: 'Courier Demo',
        phone: '+7 (999) 000-00-02',
        role: 'courier',
      }),
      createUser({
        id: crypto.randomUUID(),
        login: 'demo',
        password: 'demo12345',
        fullName: 'Client Demo',
        phone: '+7 (999) 000-00-03',
        role: 'client',
      }),
    ],
    products: [
      {
        id: 'gas-10l',
        title: 'Баллон 10л + гелий',
        subtitle: 'Главная позиция для аренды на мероприятия и декор.',
        category: 'gas',
        price: 4900,
        stock: 9,
        unitLabel: 'шт',
        requiresReturn: true,
        featured: true,
        tint: '#FF7AA8',
      },
      {
        id: 'gas-40l',
        title: 'Баллон 40л + гелий',
        subtitle: 'Для объёмных мероприятий и коммерческого использования.',
        category: 'gas',
        price: 9800,
        stock: 4,
        unitLabel: 'шт',
        requiresReturn: true,
        featured: true,
        tint: '#FFB26B',
      },
      {
        id: 'regulator-pro',
        title: 'Редуктор Pro',
        subtitle: 'Точная настройка потока для монтажа и декора.',
        category: 'equipment',
        price: 2200,
        stock: 7,
        unitLabel: 'шт',
        requiresReturn: false,
        featured: false,
        tint: '#FFD36F',
      },
      {
        id: 'latex-pack',
        title: 'Набор латексных шаров',
        subtitle: 'Пачка из 100 шаров для базовой коммерческой выдачи.',
        category: 'consumable',
        price: 1300,
        stock: 18,
        unitLabel: 'уп',
        requiresReturn: false,
        featured: false,
        tint: '#F781A7',
      },
      {
        id: 'safety-kit',
        title: 'Комплект безопасности',
        subtitle: 'Чехол, перчатки и памятка для безопасной перевозки.',
        category: 'consumable',
        price: 900,
        stock: 12,
        unitLabel: 'шт',
        requiresReturn: false,
        featured: false,
        tint: '#C9F5D2',
      },
      {
        id: 'arch-stand-mini',
        title: 'Стойка для фотозоны Mini',
        subtitle:
          'Возвратная конструкция для гирлянд, welcome-зон и свадебных стоек.',
        category: 'equipment',
        price: 3500,
        stock: 3,
        unitLabel: 'шт',
        requiresReturn: true,
        featured: true,
        tint: '#FFB26B',
      },
      {
        id: 'foil-star-set',
        title: 'Фольгированные звезды Set',
        subtitle:
          'Набор акцентных фигур для витрин, фотозон и подарочных композиций.',
        category: 'consumable',
        price: 1900,
        stock: 14,
        unitLabel: 'уп',
        requiresReturn: false,
        featured: true,
        tint: '#FF89B5',
      },
      {
        id: 'ribbon-weight-kit',
        title: 'Ленты и грузы комплект',
        subtitle: 'Базовый набор для закрепления шаров и готовых связок.',
        category: 'consumable',
        price: 650,
        stock: 24,
        unitLabel: 'компл',
        requiresReturn: false,
        featured: false,
        tint: '#FFE5A4',
      },
    ],
    orders: [],
  };
}

function createUser({ id, login, password, fullName, phone, role }) {
  return {
    id,
    login,
    passwordHash: hashPassword(password),
    fullName,
    phone,
    role,
    createdAt: new Date().toISOString(),
  };
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto
    .pbkdf2Sync(password, salt, 120000, 32, 'sha256')
    .toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, storedHash) {
  const [salt, expectedHash] = String(storedHash).split(':');
  if (!salt || !expectedHash) return false;
  const actualHash = crypto
    .pbkdf2Sync(password, salt, 120000, 32, 'sha256')
    .toString('hex');
  return crypto.timingSafeEqual(
    Buffer.from(actualHash, 'utf8'),
    Buffer.from(expectedHash, 'utf8'),
  );
}

function signToken(user) {
  const header = encodeBase64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = encodeBase64Url(
    JSON.stringify({
      sub: user.id,
      role: user.role,
      exp: Date.now() + 7 * 24 * 60 * 60 * 1000,
    }),
  );
  const signature = crypto
    .createHmac('sha256', TOKEN_SECRET)
    .update(`${header}.${payload}`)
    .digest('base64url');
  return `${header}.${payload}.${signature}`;
}

function verifyToken(token) {
  const [header, payload, signature] = String(token).split('.');
  if (!header || !payload || !signature) {
    throw httpError(401, 'Некорректный токен.');
  }

  const expected = crypto
    .createHmac('sha256', TOKEN_SECRET)
    .update(`${header}.${payload}`)
    .digest('base64url');

  if (
    !crypto.timingSafeEqual(
      Buffer.from(signature, 'utf8'),
      Buffer.from(expected, 'utf8'),
    )
  ) {
    throw httpError(401, 'Подпись токена не совпадает.');
  }

  const parsed = JSON.parse(decodeBase64Url(payload));
  if (parsed.exp < Date.now()) {
    throw httpError(401, 'Сессия истекла.');
  }
  return parsed;
}

function getCurrentUser(req, store) {
  const auth = req.headers.authorization || '';
  if (!auth.startsWith('Bearer ')) return null;
  const token = auth.slice('Bearer '.length);
  const payload = verifyToken(token);
  return store.users.find((user) => user.id === payload.sub) || null;
}

function sanitizeUser(user) {
  return {
    id: user.id,
    login: user.login,
    fullName: user.fullName,
    phone: user.phone,
    role: user.role,
    createdAt: user.createdAt,
  };
}

function ensureAuthenticated(user) {
  if (!user) {
    throw httpError(401, 'Нужна авторизация.');
  }
}

function ensureRole(user, roles) {
  ensureAuthenticated(user);
  if (!roles.includes(user.role)) {
    throw httpError(403, 'Недостаточно прав.');
  }
}

function nextOrderCode(index) {
  return `GX-${String(index).padStart(4, '0')}`;
}

function parseJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1000000) {
        reject(httpError(413, 'Слишком большой запрос.'));
      }
    });
    req.on('end', () => {
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (_) {
        reject(httpError(400, 'Некорректный JSON.'));
      }
    });
    req.on('error', () => reject(httpError(400, 'Не удалось прочитать тело.')));
  });
}

function json(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
  });
  res.end(JSON.stringify(payload));
}

function setCorsHeaders(req, res) {
  const requestOrigin = req.headers.origin;
  const allowOrigin =
    CORS_ORIGIN === '*' ? '*' : requestOrigin === CORS_ORIGIN ? CORS_ORIGIN : '';

  if (allowOrigin) {
    res.setHeader('Access-Control-Allow-Origin', allowOrigin);
  }
  if (CORS_ORIGIN !== '*') {
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET, HEAD, POST, PATCH, OPTIONS',
  );
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function encodeBase64Url(value) {
  return Buffer.from(value, 'utf8').toString('base64url');
}

function decodeBase64Url(value) {
  return Buffer.from(value, 'base64url').toString('utf8');
}
