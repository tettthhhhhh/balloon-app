const cors = require('cors');
const express = require('express');

const { APP_SECRET, CORS_ORIGINS } = require('./config/env');
const { asyncRoute } = require('./lib/async-route');
const { HttpError } = require('./lib/http-error');
const {
  attachCurrentUser,
  ensureAuthenticated,
  ensureRole,
} = require('./middleware/auth');
const { getConfig, updateConfig } = require('./services/config-service');
const { register, signIn } = require('./services/auth-service');
const {
  buildVerificationResponseForUser,
  resendVerification,
  confirmVerification,
} = require('./services/verification-service');
const { listProducts, updateProduct } = require('./services/product-service');
const {
  listOrders,
  createOrder,
  signContractStub,
  rejectContractStub,
  confirmPaymentStub,
  failPaymentStub,
  issueOrder,
  completeOrder,
  forceCompleteOrder,
} = require('./services/order-service');
const {
  getOrderContract,
  getContractById,
  issueContractAccessLink,
  resolveContractDocument,
  renderContractDocumentHtml,
  renderContractDocumentPdf,
  buildContractPdfFilename,
} = require('./services/contract-service');
const { getOrderPayment } = require('./services/payment-service');
const { getDashboardStats } = require('./services/dashboard-service');
const {
  listRiskOverview,
  blockUserOrders,
  unblockUserOrders,
} = require('./services/risk-service');

function isLocalDevOrigin(origin) {
  try {
    const url = new URL(origin);
    return (
      url.hostname === 'localhost' ||
      url.hostname === '127.0.0.1' ||
      url.hostname === '0.0.0.0' ||
      url.hostname === '[::1]' ||
      url.hostname === '::1'
    );
  } catch (_) {
    return false;
  }
}

function buildCorsOriginResolver() {
  if (CORS_ORIGINS === '*') {
    return '*';
  }

  return (origin, callback) => {
    if (!origin || isLocalDevOrigin(origin) || CORS_ORIGINS.includes(origin)) {
      callback(null, true);
      return;
    }
    callback(new HttpError(403, 'CORS origin is not allowed.'));
  };
}

function createApp() {
  const app = express();
  const stubSystemActor = { id: 'stub-system', role: 'admin' };

  app.use(
    cors({
      origin: buildCorsOriginResolver(),
      methods: ['GET', 'HEAD', 'POST', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'x-stub-secret'],
    }),
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(attachCurrentUser);

  app.get('/api/health', (_req, res) => {
    res.json({ ok: true });
  });

  app.get(
    '/api/config',
    asyncRoute(async (_req, res) => {
      res.json({ config: await getConfig() });
    }),
  );

  app.patch(
    '/api/config',
    ensureRole('admin'),
    asyncRoute(async (req, res) => {
      res.json({ config: await updateConfig(req.body || {}) });
    }),
  );

  app.post(
    '/api/auth/register',
    asyncRoute(async (req, res) => {
      const session = await register(req.body || {});
      res.status(201).json(session);
    }),
  );

  app.post(
    '/api/auth/login',
    asyncRoute(async (req, res) => {
      res.json(await signIn(req.body || {}));
    }),
  );

  app.get(
    '/api/auth/me',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json(await buildVerificationResponseForUser(req.currentUser.id));
    }),
  );

  app.post(
    '/api/auth/verification/resend',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json(await resendVerification(req.currentUser, req.body || {}));
    }),
  );

  app.post(
    '/api/auth/verification/confirm',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json(await confirmVerification(req.currentUser, req.body || {}));
    }),
  );

  app.get(
    '/api/products',
    asyncRoute(async (req, res) => {
      res.json({ products: await listProducts(req.currentUser || null) });
    }),
  );

  app.patch(
    '/api/products/:productId',
    ensureRole('admin'),
    asyncRoute(async (req, res) => {
      res.json({
        product: await updateProduct(req.params.productId, req.body || {}),
      });
    }),
  );

  app.get(
    '/api/orders',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({ orders: await listOrders(req.currentUser) });
    }),
  );

  app.post(
    '/api/orders',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.status(201).json({
        order: await createOrder(req.currentUser, req.body || {}),
      });
    }),
  );

  app.get(
    '/api/orders/:orderId/contract',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        contract: await getOrderContract(req.params.orderId, req.currentUser),
      });
    }),
  );

  app.post(
    '/api/contracts/:contractId/access-link',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        access: await issueContractAccessLink(
          req.params.contractId,
          req.currentUser,
        ),
      });
    }),
  );

  app.get(
    '/api/contracts/:contractId/document',
    asyncRoute(async (req, res) => {
      const format = req.query.format === 'pdf' ? 'pdf' : 'html';
      const download = req.query.download === '1';
      const contract = await resolveContractDocument(req.params.contractId, {
        currentUser: req.currentUser,
        token: String(req.query.token || ''),
        format,
        download,
        userAgent: req.headers['user-agent'] || '',
        forwardedFor: req.headers['x-forwarded-for'] || '',
        remoteAddress: req.socket?.remoteAddress || '',
      });

      if (format === 'pdf') {
        const filename = buildContractPdfFilename(contract);
        res.type('pdf');
        res.setHeader(
          'Content-Disposition',
          `${download ? 'attachment' : 'inline'}; filename="${filename}"`,
        );
        res.send(renderContractDocumentPdf(contract));
        return;
      }

      res.type('html').send(renderContractDocumentHtml(contract));
    }),
  );

  app.post(
    '/api/orders/:orderId/contracts/sign-stub',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        order: await signContractStub(
          req.params.orderId,
          req.currentUser,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/orders/:orderId/contracts/reject-stub',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        order: await rejectContractStub(
          req.params.orderId,
          req.currentUser,
          req.body || {},
        ),
      });
    }),
  );

  app.get(
    '/api/orders/:orderId/payment',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        payment: await getOrderPayment(req.params.orderId, req.currentUser),
      });
    }),
  );

  app.post(
    '/api/orders/:orderId/payments/confirm-stub',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        order: await confirmPaymentStub(
          req.params.orderId,
          req.currentUser,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/orders/:orderId/payments/fail-stub',
    ensureAuthenticated,
    asyncRoute(async (req, res) => {
      res.json({
        order: await failPaymentStub(
          req.params.orderId,
          req.currentUser,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/webhooks/stub/contracts/signed',
    asyncRoute(async (req, res) => {
      if ((req.headers['x-stub-secret'] || '') !== APP_SECRET) {
        throw new HttpError(401, 'Stub webhook secret is invalid.');
      }
      res.json({
        order: await signContractStub(
          String(req.body?.orderId || ''),
          stubSystemActor,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/webhooks/stub/contracts/rejected',
    asyncRoute(async (req, res) => {
      if ((req.headers['x-stub-secret'] || '') !== APP_SECRET) {
        throw new HttpError(401, 'Stub webhook secret is invalid.');
      }
      res.json({
        order: await rejectContractStub(
          String(req.body?.orderId || ''),
          stubSystemActor,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/webhooks/stub/payments/paid',
    asyncRoute(async (req, res) => {
      if ((req.headers['x-stub-secret'] || '') !== APP_SECRET) {
        throw new HttpError(401, 'Stub webhook secret is invalid.');
      }
      res.json({
        order: await confirmPaymentStub(
          String(req.body?.orderId || ''),
          stubSystemActor,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/webhooks/stub/payments/failed',
    asyncRoute(async (req, res) => {
      if ((req.headers['x-stub-secret'] || '') !== APP_SECRET) {
        throw new HttpError(401, 'Stub webhook secret is invalid.');
      }
      res.json({
        order: await failPaymentStub(
          String(req.body?.orderId || ''),
          stubSystemActor,
          req.body || {},
        ),
      });
    }),
  );

  app.post(
    '/api/orders/:orderId/issue',
    ensureRole('courier', 'admin'),
    asyncRoute(async (req, res) => {
      res.json({
        order: await issueOrder(req.params.orderId, req.body || {}),
      });
    }),
  );

  app.post(
    '/api/orders/:orderId/complete',
    ensureRole('courier', 'admin'),
    asyncRoute(async (req, res) => {
      res.json({ order: await completeOrder(req.params.orderId, req.body || {}) });
    }),
  );

  app.post(
    '/api/admin/orders/:orderId/force-complete',
    ensureRole('admin'),
    asyncRoute(async (req, res) => {
      res.json({
        order: await forceCompleteOrder(
          req.params.orderId,
          req.currentUser,
          req.body || {},
        ),
      });
    }),
  );

  app.get(
    '/api/dashboard',
    ensureRole('admin'),
    asyncRoute(async (_req, res) => {
      res.json({ stats: await getDashboardStats() });
    }),
  );

  app.get(
    '/api/admin/risk-overview',
    ensureRole('admin'),
    asyncRoute(async (_req, res) => {
      res.json(await listRiskOverview());
    }),
  );

  app.post(
    '/api/admin/users/:userId/block-orders',
    ensureRole('admin'),
    asyncRoute(async (req, res) => {
      res.json({
        user: await blockUserOrders(req.params.userId, {
          ...req.body,
          actor: req.currentUser,
        }),
      });
    }),
  );

  app.post(
    '/api/admin/users/:userId/unblock-orders',
    ensureRole('admin'),
    asyncRoute(async (req, res) => {
      res.json({
        user: await unblockUserOrders(req.params.userId, {
          ...req.body,
          actor: req.currentUser,
        }),
      });
    }),
  );

  app.use((_req, _res, next) => {
    next(new HttpError(404, 'Маршрут не найден.'));
  });

  app.use((error, _req, res, _next) => {
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({
      message: error.message || 'Внутренняя ошибка сервера.',
    });
  });

  return app;
}

module.exports = {
  createApp,
};
