const crypto = require('crypto');

const { query } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const { makeStubExternalId } = require('../lib/security');
const {
  serializePayment,
  serializePaymentEvent,
} = require('../lib/serializers');

async function recordPaymentEvent(
  connection,
  { paymentId, eventType, status, amount, providerEventId, payload },
) {
  await connection.execute(
    `
      INSERT INTO payment_events (
        id,
        payment_id,
        event_type,
        status,
        amount,
        provider_event_id,
        payload_json,
        created_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))
    `,
    [
      crypto.randomUUID(),
      paymentId,
      eventType,
      status,
      amount == null ? null : Number(amount),
      providerEventId || null,
      payload == null ? null : JSON.stringify(payload),
    ],
  );
}

async function createPendingPayment(
  connection,
  { orderId, paymentMethod, totalAmount, paymentMask },
) {
  const paymentId = crypto.randomUUID();
  const now = new Date();
  const externalId = makeStubExternalId('payment');
  const providerReference = makeStubExternalId('txn');

  await connection.execute(
    `
      INSERT INTO payments (
        id,
        order_id,
        provider,
        method,
        status,
        amount,
        currency,
        payment_mask,
        external_id,
        provider_reference,
        failure_reason,
        stub_mode,
        created_at,
        paid_at,
        last_event_at,
        updated_at
      )
      VALUES (?, ?, 'stub-pay', ?, 'pending', ?, 'RUB', ?, ?, ?, NULL, 1, ?, NULL, ?, ?)
    `,
    [
      paymentId,
      orderId,
      paymentMethod,
      totalAmount,
      paymentMask,
      externalId,
      providerReference,
      now,
      now,
      now,
    ],
  );

  await recordPaymentEvent(connection, {
    paymentId,
    eventType: 'created',
    status: 'pending',
    amount: totalAmount,
    providerEventId: providerReference,
    payload: {
      paymentMethod,
      paymentMask,
      stubMode: true,
    },
  });

  return { id: paymentId, providerReference };
}

async function findLatestPaymentByOrder(
  orderId,
  connection,
  { forUpdate = false } = {},
) {
  const suffix = forUpdate ? '\n      FOR UPDATE' : '';
  const rows = await query(
    `
      SELECT
        p.id,
        p.order_id,
        p.provider,
        p.method,
        p.status,
        p.amount,
        p.currency,
        p.payment_mask,
        p.external_id,
        p.provider_reference,
        p.failure_reason,
        p.stub_mode,
        p.created_at,
        p.paid_at,
        p.last_event_at,
        p.updated_at
      FROM payments p
      WHERE p.order_id = ?
      ORDER BY p.created_at DESC
      LIMIT 1${suffix}
    `,
    [orderId],
    connection,
  );

  return rows[0] || null;
}

async function loadPaymentEvents(paymentId, connection) {
  const rows = await query(
    `
      SELECT
        id,
        payment_id,
        event_type,
        status,
        amount,
        provider_event_id,
        payload_json,
        created_at
      FROM payment_events
      WHERE payment_id = ?
      ORDER BY created_at ASC
    `,
    [paymentId],
    connection,
  );

  return rows.map(serializePaymentEvent);
}

async function markPaymentPaid(connection, payment, payload = {}) {
  const paymentMethod = String(payload.paymentMethod || payment.method || 'card_demo');
  const paymentMask = String(payload.paymentMask || '').trim();
  const providerReference =
    String(payload.providerReference || '').trim() ||
    payment.provider_reference ||
    makeStubExternalId('txn');

  await connection.execute(
    `
      UPDATE payments
      SET
        method = ?,
        payment_mask = ?,
        status = 'paid',
        provider_reference = ?,
        failure_reason = NULL,
        paid_at = CURRENT_TIMESTAMP(3),
        last_event_at = CURRENT_TIMESTAMP(3),
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE id = ?
    `,
    [paymentMethod, paymentMask, providerReference, payment.id],
  );

  await recordPaymentEvent(connection, {
    paymentId: payment.id,
    eventType: 'paid',
    status: 'paid',
    amount: payment.amount,
    providerEventId: providerReference,
    payload: {
      paymentMethod,
      paymentMask,
      provider: payment.provider,
    },
  });
}

async function markPaymentFailed(connection, payment, payload = {}) {
  const reason = String(payload.reason || '').trim() || 'stub failure';
  const providerReference =
    String(payload.providerReference || '').trim() ||
    payment.provider_reference ||
    makeStubExternalId('txn');

  await connection.execute(
    `
      UPDATE payments
      SET
        status = 'failed',
        provider_reference = ?,
        failure_reason = ?,
        last_event_at = CURRENT_TIMESTAMP(3),
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE id = ?
    `,
    [providerReference, reason, payment.id],
  );

  await recordPaymentEvent(connection, {
    paymentId: payment.id,
    eventType: 'failed',
    status: 'failed',
    amount: payment.amount,
    providerEventId: providerReference,
    payload: { reason },
  });
}

async function assertOrderAccess(orderId, currentUser, connection) {
  const rows = await query(
    `
      SELECT
        id,
        user_id
      FROM orders
      WHERE id = ?
      LIMIT 1
    `,
    [orderId],
    connection,
  );

  const order = rows[0];
  if (!order) {
    throw httpError(404, 'Заказ не найден.');
  }
  if (
    currentUser.role !== 'admin' &&
    currentUser.role !== 'courier' &&
    currentUser.id !== order.user_id
  ) {
    throw httpError(403, 'Недостаточно прав для просмотра платежа.');
  }

  return order;
}

async function getOrderPayment(orderId, currentUser) {
  await assertOrderAccess(orderId, currentUser);
  const payment = await findLatestPaymentByOrder(orderId);
  if (!payment) {
    throw httpError(404, 'Платёж не найден.');
  }
  const events = await loadPaymentEvents(payment.id);
  return serializePayment(payment, events);
}

module.exports = {
  createPendingPayment,
  findLatestPaymentByOrder,
  loadPaymentEvents,
  markPaymentPaid,
  markPaymentFailed,
  recordPaymentEvent,
  getOrderPayment,
};
