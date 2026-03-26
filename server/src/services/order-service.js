const crypto = require('crypto');

const { query, withTransaction } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const {
  serializeOrder,
  serializeOrderItem,
  serializeCylinderLog,
} = require('../lib/serializers');
const {
  createPendingContract,
  findLatestContractByOrder,
  markContractSigned,
  markContractRejected,
} = require('./contract-service');
const {
  createPendingPayment,
  findLatestPaymentByOrder,
  markPaymentPaid,
  markPaymentFailed,
} = require('./payment-service');
const {
  ensureOrderCreationAllowed,
  insertRiskEvent,
  syncUserRiskState,
} = require('./risk-service');

function normalizeDeliveryType(value) {
  return value === 'delivery' ? 'delivery' : 'pickup';
}

function normalizeSerialList(payload) {
  const fromList = Array.isArray(payload?.cylinderSerials)
    ? payload.cylinderSerials
    : [];
  const fromSingle = String(payload?.cylinderSerial || '').trim();
  const combined = fromList.map((value) => String(value || '').trim());

  if (fromSingle) {
    combined.push(fromSingle);
  }

  return combined.filter(Boolean);
}

function normalizeReturnCodeList(payload) {
  const fromList = Array.isArray(payload?.returnedCodes)
    ? payload.returnedCodes
    : [];
  const fromSingle = String(payload?.returnedCode || '').trim();
  const combined = fromList.map((value) => String(value || '').trim());

  if (fromSingle) {
    combined.push(fromSingle);
  }

  return combined.filter(Boolean);
}

function normalizeCode(value) {
  let normalized = String(value || '').trim().toUpperCase();

  for (const prefix of ['INDGAS_ORDER:', 'INDGAS_CYLINDER:']) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.slice(prefix.length).trim();
      break;
    }
  }

  const cylinderMatch = normalized.match(/(GX-\d{4,}-\d{2,})/);
  if (cylinderMatch) {
    return cylinderMatch[1];
  }

  const orderMatch = normalized.match(/(GX-\d{4,})/);
  if (orderMatch) {
    return orderMatch[1];
  }

  return normalized;
}

async function getNextOrderCode(connection) {
  const rows = await query(
    `
      SELECT
        COALESCE(MAX(CAST(SUBSTRING(order_code, 4) AS UNSIGNED)), 0) AS last_number
      FROM orders
      WHERE order_code REGEXP '^GX-[0-9]+$'
    `,
    [],
    connection,
  );
  const nextNumber = Number(rows[0]?.last_number || 0) + 1;
  return `GX-${String(nextNumber).padStart(4, '0')}`;
}

async function loadOrders(whereSql, params, connection) {
  const orderRows = await query(
    `
      SELECT
        o.id,
        o.order_code,
        o.user_id,
        o.customer_name,
        o.customer_phone,
        o.delivery_type,
        o.location,
        o.payment_method,
        o.payment_mask,
        o.status,
        o.total_amount,
        o.cylinder_serial,
        o.created_at,
        o.issued_at,
        o.returned_at,
        (
          SELECT c.id
          FROM contracts c
          WHERE c.order_id = o.id
          ORDER BY c.created_at DESC
          LIMIT 1
        ) AS contract_id,
        (
          SELECT c.status
          FROM contracts c
          WHERE c.order_id = o.id
          ORDER BY c.created_at DESC
          LIMIT 1
        ) AS contract_status,
        (
          SELECT c.file_url
          FROM contracts c
          WHERE c.order_id = o.id
          ORDER BY c.created_at DESC
          LIMIT 1
        ) AS contract_file_url,
        (
          SELECT p.id
          FROM payments p
          WHERE p.order_id = o.id
          ORDER BY p.created_at DESC
          LIMIT 1
        ) AS payment_id,
        (
          SELECT p.status
          FROM payments p
          WHERE p.order_id = o.id
          ORDER BY p.created_at DESC
          LIMIT 1
        ) AS payment_status
      FROM orders o
      WHERE ${whereSql}
      ORDER BY o.created_at DESC
    `,
    params,
    connection,
  );

  if (orderRows.length === 0) {
    return [];
  }

  const orderIds = orderRows.map((row) => row.id);
  const placeholders = orderIds.map(() => '?').join(', ');
  const itemRows = await query(
    `
      SELECT
        id,
        order_id,
        product_id,
        title_snapshot,
        quantity,
        unit_price,
        requires_return
      FROM order_items
      WHERE order_id IN (${placeholders})
      ORDER BY created_at ASC, id ASC
    `,
    orderIds,
    connection,
  );

  const itemsByOrder = new Map();
  for (const row of itemRows) {
    const current = itemsByOrder.get(row.order_id) || [];
    current.push(serializeOrderItem(row));
    itemsByOrder.set(row.order_id, current);
  }

  const cylinderRows = await query(
    `
      SELECT
        id,
        order_id,
        order_item_id,
        qr_code,
        cylinder_serial_number,
        quantity,
        status,
        issued_at,
        returned_at,
        created_at
      FROM cylinder_logs
      WHERE order_id IN (${placeholders})
      ORDER BY created_at ASC, id ASC
    `,
    orderIds,
    connection,
  );

  const cylinderLogsByOrder = new Map();
  for (const row of cylinderRows) {
    const current = cylinderLogsByOrder.get(row.order_id) || [];
    current.push(serializeCylinderLog(row));
    cylinderLogsByOrder.set(row.order_id, current);
  }

  return orderRows.map((row) =>
    serializeOrder(
      row,
      itemsByOrder.get(row.id) || [],
      cylinderLogsByOrder.get(row.id) || [],
    ),
  );
}

async function getOrderById(orderId, connection) {
  const orders = await loadOrders('o.id = ?', [orderId], connection);
  const order = orders[0];
  if (!order) {
    throw httpError(404, 'Заказ не найден.');
  }
  return order;
}

async function listOrders(currentUser) {
  if (currentUser.role === 'admin') {
    return loadOrders('1 = 1', []);
  }
  if (currentUser.role === 'courier') {
    return loadOrders("o.status IN ('paid', 'active')", []);
  }
  return loadOrders('o.user_id = ?', [currentUser.id]);
}

async function createOrder(currentUser, payload) {
  if (currentUser.email && !currentUser.email_verified_at) {
    throw httpError(403, 'Сначала подтвердите email, затем можно оформлять заказ.');
  }
  if (currentUser.phone && !currentUser.phone_verified_at) {
    throw httpError(403, 'Сначала подтвердите телефон, затем можно оформлять заказ.');
  }

  const deliveryType = normalizeDeliveryType(payload.deliveryType);
  const location = String(payload.location || '').trim();
  const paymentMethod = String(payload.paymentMethod || 'card_demo');
  const paymentMask = String(payload.paymentMask || '').trim();
  const items = Array.isArray(payload.items) ? payload.items : [];

  if (!location) {
    throw httpError(400, 'Нужно указать точку получения или адрес.');
  }
  if (items.length === 0) {
    throw httpError(400, 'Корзина не должна быть пустой.');
  }

  let orderId = null;

  await withTransaction(async (connection) => {
    await ensureOrderCreationAllowed(currentUser.id, connection);

    const productIds = [...new Set(items.map((item) => item.productId))];
    const placeholders = productIds.map(() => '?').join(', ');
    const productRows = await query(
      `
        SELECT
          id,
          title,
          price,
          stock,
          requires_return
        FROM products
        WHERE id IN (${placeholders})
      `,
      productIds,
      connection,
    );

    const productsById = new Map(productRows.map((row) => [row.id, row]));
    const orderLines = [];
    let totalAmount = 0;

    for (const requestedItem of items) {
      const product = productsById.get(requestedItem.productId);
      const quantity = Number(requestedItem.quantity || 0);

      if (!product) {
        throw httpError(404, 'Один из товаров не найден.');
      }
      if (!Number.isInteger(quantity) || quantity <= 0) {
        throw httpError(400, 'Некорректное количество товара.');
      }
      if (Number(product.stock) < quantity) {
        throw httpError(
          409,
          `Недостаточно товара на складе: ${product.title}.`,
        );
      }

      totalAmount += Number(product.price) * quantity;
      orderLines.push({
        id: crypto.randomUUID(),
        productId: product.id,
        title: product.title,
        quantity,
        unitPrice: Number(product.price),
        requiresReturn: Boolean(product.requires_return),
      });
    }

    orderId = crypto.randomUUID();
    const orderCode = await getNextOrderCode(connection);
    const now = new Date();

    await connection.execute(
      `
        INSERT INTO orders (
          id,
          order_code,
          user_id,
          customer_name,
          customer_phone,
          delivery_type,
          location,
          payment_method,
          payment_mask,
          status,
          total_amount,
          stub_flow,
          cylinder_serial,
          created_at,
          updated_at,
          issued_at,
          returned_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'awaiting_signature', ?, 1, NULL, ?, ?, NULL, NULL)
      `,
      [
        orderId,
        orderCode,
        currentUser.id,
        currentUser.full_name,
        currentUser.phone || '',
        deliveryType,
        location,
        paymentMethod,
        paymentMask,
        totalAmount,
        now,
        now,
      ],
    );

    for (const line of orderLines) {
      await connection.execute(
        `
          INSERT INTO order_items (
            id,
            order_id,
            product_id,
            title_snapshot,
            quantity,
            unit_price,
            requires_return
          )
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `,
        [
          line.id,
          orderId,
          line.productId,
          line.title,
          line.quantity,
          line.unitPrice,
          line.requiresReturn ? 1 : 0,
        ],
      );
    }

    await createPendingContract(connection, {
      order: {
        id: orderId,
        orderCode,
        customerName: currentUser.full_name,
        customerPhone: currentUser.phone || '',
        deliveryType,
        location,
        paymentMethod,
        totalAmount,
      },
      items: orderLines,
      currentUser,
    });

    await createPendingPayment(connection, {
      orderId,
      paymentMethod,
      totalAmount,
      paymentMask,
    });
  });

  return getOrderById(orderId);
}

async function signContractStub(orderId, currentUser, metadata = {}) {
  await withTransaction(async (connection) => {
    const rows = await query(
      `
        SELECT
          id,
          user_id,
          status
        FROM orders
        WHERE id = ?
        LIMIT 1
        FOR UPDATE
      `,
      [orderId],
      connection,
    );

    const order = rows[0];
    if (!order) {
      throw httpError(404, 'Заказ не найден.');
    }
    if (currentUser.role !== 'admin' && currentUser.id !== order.user_id) {
      throw httpError(403, 'Недостаточно прав для подписи этого заказа.');
    }
    if (order.status === 'paid' || order.status === 'active' || order.status === 'completed') {
      return;
    }
    if (order.status !== 'awaiting_signature') {
      throw httpError(409, 'Договор нельзя подписать в текущем статусе.');
    }

    const contract = await findLatestContractByOrder(orderId, connection, {
      forUpdate: true,
    });
    if (!contract) {
      throw httpError(404, 'Договор для заказа не найден.');
    }
    if (contract.status === 'signed') {
      return;
    }

    await markContractSigned(connection, contract, metadata);

    await connection.execute(
      `
        UPDATE orders
        SET
          status = 'awaiting_payment',
          updated_at = CURRENT_TIMESTAMP(3)
        WHERE id = ?
      `,
      [orderId],
    );
  });

  return getOrderById(orderId);
}

async function rejectContractStub(orderId, currentUser, metadata = {}) {
  await withTransaction(async (connection) => {
    const rows = await query(
      `
        SELECT
          id,
          user_id,
          status
        FROM orders
        WHERE id = ?
        LIMIT 1
        FOR UPDATE
      `,
      [orderId],
      connection,
    );
    const order = rows[0];

    if (!order) {
      throw httpError(404, 'Заказ не найден.');
    }
    if (currentUser.role !== 'admin' && currentUser.id !== order.user_id) {
      throw httpError(403, 'Недостаточно прав для отклонения договора.');
    }
    if (order.status === 'active' || order.status === 'completed') {
      throw httpError(409, 'Нельзя отклонить договор после выдачи заказа.');
    }

    const contract = await findLatestContractByOrder(orderId, connection, {
      forUpdate: true,
    });
    if (!contract) {
      throw httpError(404, 'Договор для заказа не найден.');
    }

    await markContractRejected(connection, contract, metadata);

    await connection.execute(
      `
        UPDATE orders
        SET
          status = 'blocked',
          updated_at = CURRENT_TIMESTAMP(3)
        WHERE id = ?
      `,
      [orderId],
    );
  });

  return getOrderById(orderId);
}

async function confirmPaymentStub(orderId, currentUser, payload = {}) {
  const paymentMethod = String(payload.paymentMethod || 'card_demo');
  const paymentMask = String(payload.paymentMask || '').trim();

  await withTransaction(async (connection) => {
    const rows = await query(
      `
        SELECT
          o.id,
          o.order_code,
          o.user_id,
          o.status,
          c.status AS contract_status
        FROM orders o
        INNER JOIN contracts c ON c.order_id = o.id
        WHERE o.id = ?
        LIMIT 1
        FOR UPDATE
      `,
      [orderId],
      connection,
    );

    const order = rows[0];
    if (!order) {
      throw httpError(404, 'Заказ не найден.');
    }
    if (currentUser.role !== 'admin' && currentUser.id !== order.user_id) {
      throw httpError(403, 'Недостаточно прав для оплаты этого заказа.');
    }
    if (order.status === 'paid' || order.status === 'active' || order.status === 'completed') {
      return;
    }
    if (order.contract_status !== 'signed') {
      throw httpError(409, 'Сначала нужно подписать договор.');
    }
    if (
      order.status !== 'awaiting_payment' &&
      order.status !== 'awaiting_signature'
    ) {
      throw httpError(409, 'Оплата недоступна в текущем статусе.');
    }

    const lineRows = await query(
      `
        SELECT
          oi.id,
          oi.product_id,
          oi.quantity,
          oi.requires_return,
          p.title,
          p.stock
        FROM order_items oi
        INNER JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        FOR UPDATE
      `,
      [orderId],
      connection,
    );

    for (const line of lineRows) {
      if (Number(line.stock) < Number(line.quantity)) {
        throw httpError(
          409,
          `Недостаточно товара на складе: ${line.title}.`,
        );
      }
    }

    for (const line of lineRows) {
      await connection.execute(
        'UPDATE products SET stock = stock - ? WHERE id = ?',
        [Number(line.quantity), line.product_id],
      );
    }

    const returnableRows = lineRows.filter((row) => Boolean(row.requires_return));
    if (returnableRows.length > 0) {
      const existingLogs = await query(
        `
          SELECT id
          FROM cylinder_logs
          WHERE order_id = ? AND status = 'reserved'
          LIMIT 1
        `,
        [orderId],
        connection,
      );

      if (existingLogs.length === 0) {
        let sequence = 1;
        for (const line of returnableRows) {
          const quantity = Number(line.quantity || 0);
          for (let index = 0; index < quantity; index += 1) {
            const qrCode = `${order.order_code}-${String(sequence).padStart(2, '0')}`;
            await connection.execute(
              `
                INSERT INTO cylinder_logs (
                  id,
                  order_id,
                  order_item_id,
                  qr_code,
                  cylinder_serial_number,
                  quantity,
                  status,
                  issued_at,
                  returned_at,
                  created_at,
                  updated_at
                )
                VALUES (?, ?, ?, ?, 'UNASSIGNED', 1, 'reserved', NULL, NULL, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3))
              `,
              [crypto.randomUUID(), orderId, line.id, qrCode],
            );
            sequence += 1;
          }
        }
      }
    }

    const payment = await findLatestPaymentByOrder(orderId, connection, {
      forUpdate: true,
    });
    if (!payment) {
      throw httpError(404, 'Платёж для заказа не найден.');
    }

    await markPaymentPaid(connection, payment, {
      paymentMethod,
      paymentMask,
      providerReference: payload.providerReference,
    });

    await connection.execute(
      `
        UPDATE orders
        SET
          payment_method = ?,
          payment_mask = ?,
          status = 'paid',
          updated_at = CURRENT_TIMESTAMP(3)
        WHERE id = ?
      `,
      [paymentMethod, paymentMask, orderId],
    );
  });

  return getOrderById(orderId);
}

async function failPaymentStub(orderId, currentUser, payload = {}) {
  await withTransaction(async (connection) => {
    const rows = await query(
      `
        SELECT
          o.id,
          o.user_id,
          o.status,
          c.status AS contract_status
        FROM orders o
        INNER JOIN contracts c ON c.order_id = o.id
        WHERE o.id = ?
        LIMIT 1
        FOR UPDATE
      `,
      [orderId],
      connection,
    );

    const order = rows[0];
    if (!order) {
      throw httpError(404, 'Заказ не найден.');
    }
    if (currentUser.role !== 'admin' && currentUser.id !== order.user_id) {
      throw httpError(403, 'Недостаточно прав для смены статуса платежа.');
    }
    if (order.status === 'active' || order.status === 'completed') {
      throw httpError(409, 'Нельзя пометить платёж failed после выдачи заказа.');
    }

    const payment = await findLatestPaymentByOrder(orderId, connection, {
      forUpdate: true,
    });
    if (!payment) {
      throw httpError(404, 'Платёж для заказа не найден.');
    }

    await markPaymentFailed(connection, payment, payload);

    await connection.execute(
      `
        UPDATE orders
        SET
          status = ?,
          updated_at = CURRENT_TIMESTAMP(3)
        WHERE id = ?
      `,
      [order.contract_status === 'signed' ? 'awaiting_payment' : 'blocked', orderId],
    );
  });

  return getOrderById(orderId);
}

async function issueOrder(orderId, payload) {
  const normalizedSerials = normalizeSerialList(payload);

  await withTransaction(async (connection) => {
    const rows = await query(
      `
        SELECT
          id,
          order_code,
          status
        FROM orders
        WHERE id = ?
        FOR UPDATE
      `,
      [orderId],
      connection,
    );
    const order = rows[0];

    if (!order) {
      throw httpError(404, 'Заказ не найден.');
    }
    if (order.status !== 'paid') {
      throw httpError(409, 'Выдать можно только оплаченный заказ.');
    }

    const returnableRows = await query(
      `
        SELECT
          id,
          quantity
        FROM order_items
        WHERE order_id = ? AND requires_return = 1
        ORDER BY created_at ASC, id ASC
      `,
      [orderId],
      connection,
    );

    const requiredSerialCount = returnableRows.reduce(
      (sum, row) => sum + Number(row.quantity || 0),
      0,
    );

    if (requiredSerialCount > 0 && normalizedSerials.length !== requiredSerialCount) {
      throw httpError(
        400,
        `Нужно указать ${requiredSerialCount} серийных номер${requiredSerialCount === 1 ? '' : requiredSerialCount < 5 ? 'а' : 'ов'} для выдачи.`,
      );
    }

    await connection.execute(
      `
        UPDATE orders
        SET
          status = 'active',
          cylinder_serial = ?,
          issued_at = CURRENT_TIMESTAMP(3),
          updated_at = CURRENT_TIMESTAMP(3)
        WHERE id = ?
      `,
      [normalizedSerials.join(', ') || null, orderId],
    );

    const existingReserved = await query(
      `
        SELECT
          id,
          order_item_id,
          qr_code,
          quantity
        FROM cylinder_logs
        WHERE order_id = ? AND status = 'reserved'
        ORDER BY created_at ASC, id ASC
      `,
      [orderId],
      connection,
    );

    if (requiredSerialCount === 0) {
      return;
    }

    let cursor = 0;
    if (existingReserved.length > 0) {
      for (const log of existingReserved) {
        const quantity = Math.max(Number(log.quantity || 1), 1);

        if (quantity === 1) {
          await connection.execute(
            `
              UPDATE cylinder_logs
              SET
                cylinder_serial_number = ?,
                status = 'issued',
                issued_at = CURRENT_TIMESTAMP(3),
                updated_at = CURRENT_TIMESTAMP(3)
              WHERE id = ?
            `,
            [normalizedSerials[cursor], log.id],
          );
          cursor += 1;
          continue;
        }

        await connection.execute(
          `
            UPDATE cylinder_logs
            SET
              cylinder_serial_number = ?,
              quantity = 1,
              status = 'issued',
              issued_at = CURRENT_TIMESTAMP(3),
              updated_at = CURRENT_TIMESTAMP(3)
            WHERE id = ?
          `,
          [normalizedSerials[cursor], log.id],
        );
        cursor += 1;

        for (let index = 1; index < quantity; index += 1) {
          await connection.execute(
            `
              INSERT INTO cylinder_logs (
                id,
                order_id,
                order_item_id,
                qr_code,
                cylinder_serial_number,
                quantity,
                status,
                issued_at,
                returned_at,
                created_at,
                updated_at
              )
              VALUES (?, ?, ?, ?, ?, 1, 'issued', CURRENT_TIMESTAMP(3), NULL, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3))
            `,
            [
              crypto.randomUUID(),
              orderId,
              log.order_item_id || null,
              log.qr_code || `${order.order_code}-${String(cursor + 1).padStart(2, '0')}`,
              normalizedSerials[cursor],
            ],
          );
          cursor += 1;
        }
      }
      return;
    }

    let sequence = 1;
    for (const line of returnableRows) {
      const quantity = Number(line.quantity || 0);
      for (let index = 0; index < quantity; index += 1) {
        await connection.execute(
          `
            INSERT INTO cylinder_logs (
              id,
              order_id,
              order_item_id,
              qr_code,
              cylinder_serial_number,
              quantity,
              status,
              issued_at,
              returned_at,
              created_at,
              updated_at
            )
            VALUES (?, ?, ?, ?, ?, 1, 'issued', CURRENT_TIMESTAMP(3), NULL, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3))
          `,
          [
            crypto.randomUUID(),
            orderId,
            line.id,
            `${order.order_code}-${String(sequence).padStart(2, '0')}`,
            normalizedSerials[cursor],
          ],
        );
        sequence += 1;
        cursor += 1;
      }
    }
  });

  return getOrderById(orderId);
}

async function closeActiveOrder(
  orderId,
  connection,
  { returnedCodes = [], bypassReturnValidation = false } = {},
) {
  const rows = await query(
    `
      SELECT
        id,
        user_id,
        order_code,
        status
      FROM orders
      WHERE id = ?
      FOR UPDATE
    `,
    [orderId],
    connection,
  );
  const order = rows[0];

  if (!order) {
    throw httpError(404, 'Заказ не найден.');
  }
  if (order.status !== 'active') {
    throw httpError(409, 'Завершить можно только активный заказ.');
  }

  const issuedLogs = await query(
    `
      SELECT
        id,
        qr_code,
        cylinder_serial_number
      FROM cylinder_logs
      WHERE order_id = ? AND status = 'issued'
      ORDER BY created_at ASC, id ASC
    `,
    [orderId],
    connection,
  );

  if (!bypassReturnValidation && issuedLogs.length > 0) {
    if (returnedCodes.length !== issuedLogs.length) {
      throw httpError(
        400,
        `Need ${issuedLogs.length} return codes to close this order.`,
      );
    }

    const remainingLogs = [...issuedLogs];
    for (const rawCode of returnedCodes) {
      const normalizedCode = normalizeCode(rawCode);
      const matchIndex = remainingLogs.findIndex((log) => {
        return (
          normalizeCode(log.qr_code) === normalizedCode ||
          normalizeCode(log.cylinder_serial_number) === normalizedCode
        );
      });

      if (matchIndex === -1) {
        throw httpError(
          400,
          `Return code ${rawCode} was not found among issued cylinders for this order.`,
        );
      }

      remainingLogs.splice(matchIndex, 1);
    }
  }

  const lines = await query(
    `
      SELECT
        product_id,
        quantity,
        requires_return
      FROM order_items
      WHERE order_id = ?
    `,
    [orderId],
    connection,
  );

  for (const line of lines) {
    if (!line.requires_return) {
      continue;
    }

    await connection.execute(
      'UPDATE products SET stock = stock + ? WHERE id = ?',
      [Number(line.quantity || 0), line.product_id],
    );
  }

  await connection.execute(
    `
      UPDATE orders
      SET
        status = 'completed',
        returned_at = CURRENT_TIMESTAMP(3),
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE id = ?
    `,
    [orderId],
  );

  await connection.execute(
    `
      UPDATE cylinder_logs
      SET
        status = 'returned',
        returned_at = CURRENT_TIMESTAMP(3),
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE order_id = ? AND status <> 'returned'
    `,
    [orderId],
  );

  await syncUserRiskState(order.user_id, connection);

  return order;
}

async function completeOrder(orderId, payload = {}) {
  const returnedCodes = normalizeReturnCodeList(payload);

  await withTransaction(async (connection) => {
    await closeActiveOrder(orderId, connection, { returnedCodes });
  });

  return getOrderById(orderId);
}

async function forceCompleteOrder(orderId, actor, payload = {}) {
  const reason =
    String(payload.reason || '').trim() ||
    'Администратор принудительно закрыл активную аренду.';

  await withTransaction(async (connection) => {
    const order = await closeActiveOrder(orderId, connection, {
      bypassReturnValidation: true,
    });

    await insertRiskEvent(connection, {
      userId: order.user_id,
      orderId: order.id,
      eventType: 'admin_force_complete',
      status: 'returned',
      payload: {
        reason,
        actorId: actor?.id || null,
        actorRole: actor?.role || null,
        orderCode: order.order_code,
      },
    });
  });

  return getOrderById(orderId);
}

module.exports = {
  listOrders,
  createOrder,
  signContractStub,
  rejectContractStub,
  confirmPaymentStub,
  failPaymentStub,
  issueOrder,
  completeOrder,
  forceCompleteOrder,
};
