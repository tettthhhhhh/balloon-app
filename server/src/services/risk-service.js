const crypto = require('crypto');

const { query, withTransaction } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const { serializeUser, toIso } = require('../lib/serializers');

const OVERDUE_RETURN_DAYS = 3;
const MANUAL_BLOCK_DEFAULT_REASON =
  'Администратор временно ограничил оформление новых заказов.';

function isActiveManualBlock(user, now = new Date()) {
  if (user.order_block_source !== 'manual') {
    return false;
  }

  if (!user.order_blocked_until) {
    return true;
  }

  return new Date(user.order_blocked_until).getTime() > now.getTime();
}

function buildOverdueReason(overdueOrders) {
  if (overdueOrders.length === 0) {
    return null;
  }

  const [firstOrder] = overdueOrders;
  if (overdueOrders.length === 1) {
    return `Есть просроченная возвратная тара по заказу ${firstOrder.order_code}. Сначала закрой возврат, затем оформляй новый заказ.`;
  }

  return `Есть ${overdueOrders.length} просроченных возврата. Ближайший проблемный заказ: ${firstOrder.order_code}. Сначала закрой активные аренды.`;
}

function parsePayload(value) {
  if (!value) {
    return null;
  }

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

async function insertRiskEvent(
  connection,
  { userId, orderId = null, eventType, status, payload },
) {
  await connection.execute(
    `
      INSERT INTO risk_events (
        id,
        user_id,
        order_id,
        event_type,
        status,
        payload_json
      )
      VALUES (?, ?, ?, ?, ?, ?)
    `,
    [
      crypto.randomUUID(),
      userId,
      orderId,
      eventType,
      status,
      payload ? JSON.stringify(payload) : null,
    ],
  );
}

async function loadRiskUser(userId, connection) {
  const rows = await query(
    `
      SELECT
        id,
        login,
        email,
        phone,
        full_name,
        role,
        email_verified_at,
        phone_verified_at,
        created_at,
        updated_at,
        order_block_source,
        order_block_reason,
        order_blocked_at,
        order_blocked_until,
        risk_last_reviewed_at
      FROM users
      WHERE id = ?
      LIMIT 1
      FOR UPDATE
    `,
    [userId],
    connection,
  );

  const user = rows[0];
  if (!user) {
    throw httpError(404, 'Пользователь не найден.');
  }

  return user;
}

async function loadClientUsers(connection) {
  return query(
    `
      SELECT
        id,
        login,
        email,
        phone,
        full_name,
        role,
        email_verified_at,
        phone_verified_at,
        created_at,
        updated_at,
        order_block_source,
        order_block_reason,
        order_blocked_at,
        order_blocked_until,
        risk_last_reviewed_at
      FROM users
      WHERE role = 'client'
      ORDER BY created_at DESC
    `,
    [],
    connection,
  );
}

async function loadOverdueReturnOrders(userId, connection) {
  return query(
    `
      SELECT
        o.id,
        o.order_code,
        o.issued_at,
        TIMESTAMPDIFF(DAY, o.issued_at, CURRENT_TIMESTAMP(3)) AS overdue_days
      FROM orders o
      WHERE o.user_id = ?
        AND o.status = 'active'
        AND o.returned_at IS NULL
        AND o.issued_at IS NOT NULL
        AND o.issued_at < DATE_SUB(CURRENT_TIMESTAMP(3), INTERVAL ? DAY)
        AND EXISTS (
          SELECT 1
          FROM order_items oi
          WHERE oi.order_id = o.id AND oi.requires_return = 1
        )
      ORDER BY o.issued_at ASC
    `,
    [userId, OVERDUE_RETURN_DAYS],
    connection,
  );
}

async function loadAllOverdueReturnOrders(connection) {
  return query(
    `
      SELECT
        o.id,
        o.user_id,
        o.order_code,
        o.customer_name,
        o.customer_phone,
        o.location,
        o.total_amount,
        o.cylinder_serial,
        o.issued_at,
        TIMESTAMPDIFF(DAY, o.issued_at, CURRENT_TIMESTAMP(3)) AS overdue_days
      FROM orders o
      WHERE o.status = 'active'
        AND o.returned_at IS NULL
        AND o.issued_at IS NOT NULL
        AND o.issued_at < DATE_SUB(CURRENT_TIMESTAMP(3), INTERVAL ? DAY)
        AND EXISTS (
          SELECT 1
          FROM order_items oi
          WHERE oi.order_id = o.id AND oi.requires_return = 1
        )
      ORDER BY o.issued_at ASC
    `,
    [OVERDUE_RETURN_DAYS],
    connection,
  );
}

async function loadActiveReturnRentals(connection) {
  return query(
    `
      SELECT
        o.id,
        o.order_code,
        o.user_id,
        u.login,
        u.full_name,
        o.customer_name,
        o.customer_phone,
        o.location,
        o.total_amount,
        logs_agg.cylinder_serials,
        o.issued_at,
        o.created_at,
        items_agg.item_count,
        items_agg.return_quantity,
        TIMESTAMPDIFF(DAY, o.issued_at, CURRENT_TIMESTAMP(3)) AS overdue_days
      FROM orders o
      INNER JOIN users u ON u.id = o.user_id
      INNER JOIN (
        SELECT
          order_id,
          SUM(quantity) AS item_count,
          SUM(CASE WHEN requires_return = 1 THEN quantity ELSE 0 END) AS return_quantity
        FROM order_items
        GROUP BY order_id
      ) AS items_agg ON items_agg.order_id = o.id
      LEFT JOIN (
        SELECT
          order_id,
          GROUP_CONCAT(
            DISTINCT CASE
              WHEN cylinder_serial_number IS NOT NULL
                AND cylinder_serial_number <> ''
                AND cylinder_serial_number <> 'UNASSIGNED'
              THEN cylinder_serial_number
            END SEPARATOR '||'
          ) AS cylinder_serials
        FROM cylinder_logs
        WHERE status = 'issued'
        GROUP BY order_id
      ) AS logs_agg ON logs_agg.order_id = o.id
      WHERE o.status = 'active'
        AND o.returned_at IS NULL
        AND items_agg.return_quantity > 0
      ORDER BY overdue_days DESC, o.issued_at ASC
    `,
    [],
    connection,
  );
}

async function loadRecentRiskEvents(connection, limit = 20) {
  return query(
    `
      SELECT
        e.id,
        e.user_id,
        e.order_id,
        e.event_type,
        e.status,
        e.payload_json,
        e.created_at,
        u.login,
        u.full_name,
        o.order_code
      FROM risk_events e
      INNER JOIN users u ON u.id = e.user_id
      LEFT JOIN orders o ON o.id = e.order_id
      ORDER BY e.created_at DESC
      LIMIT ?
    `,
    [limit],
    connection,
  );
}

function buildRiskSummary(user, overdueOrders) {
  const now = new Date();
  const manualBlockActive = isActiveManualBlock(user, now);
  const hasOverdueReturns = overdueOrders.length > 0;

  let blockSource = null;
  let blockCode = null;
  let blockReason = null;
  let blockedAt = null;
  let blockedUntil = null;

  if (manualBlockActive) {
    blockSource = 'manual';
    blockCode = 'manual_block';
    blockReason = user.order_block_reason || MANUAL_BLOCK_DEFAULT_REASON;
    blockedAt = user.order_blocked_at || now;
    blockedUntil = user.order_blocked_until || null;
  } else if (hasOverdueReturns) {
    blockSource = 'overdue_return';
    blockCode = 'overdue_return';
    blockReason = buildOverdueReason(overdueOrders);
    blockedAt =
      user.order_block_source === 'overdue_return' && user.order_blocked_at
        ? user.order_blocked_at
        : now;
  }

  return {
    canCreateOrders: blockCode == null,
    isBlocked: blockCode != null,
    blockCode,
    blockReason,
    blockSource,
    blockedAt: toIso(blockedAt),
    blockedUntil: toIso(blockedUntil),
    overdueActiveOrders: overdueOrders.length,
    overdueOrderCodes: overdueOrders.map((order) => order.order_code),
    maxOverdueDays: overdueOrders.reduce(
      (max, order) => Math.max(max, Number(order.overdue_days || 0)),
      0,
    ),
    oldestOverdueIssuedAt: toIso(overdueOrders[0]?.issued_at),
  };
}

function serializeActiveRental(row) {
  return {
    orderId: row.id,
    orderCode: row.order_code,
    userId: row.user_id,
    userLogin: row.login || '',
    userFullName: row.full_name || row.customer_name || '',
    customerName: row.customer_name || '',
    customerPhone: row.customer_phone || '',
    location: row.location || '',
    totalAmount: Number(row.total_amount || 0),
    cylinderSerials: String(row.cylinder_serials || '')
      .split('||')
      .map((item) => item.trim())
      .filter(Boolean),
    itemCount: Number(row.item_count || 0),
    returnQuantity: Number(row.return_quantity || 0),
    overdueDays: Number(row.overdue_days || 0),
    issuedAt: toIso(row.issued_at),
    createdAt: toIso(row.created_at),
    isOverdue: Number(row.overdue_days || 0) >= OVERDUE_RETURN_DAYS,
  };
}

function serializeAdminRiskEvent(row) {
  return {
    id: row.id,
    userId: row.user_id,
    orderId: row.order_id || null,
    userLogin: row.login || '',
    userFullName: row.full_name || '',
    orderCode: row.order_code || null,
    eventType: row.event_type,
    status: row.status,
    payload: parsePayload(row.payload_json),
    createdAt: toIso(row.created_at) || new Date().toISOString(),
  };
}

async function syncUserRiskState(userId, connection) {
  const user = await loadRiskUser(userId, connection);
  const overdueOrders = await loadOverdueReturnOrders(userId, connection);
  const summary = buildRiskSummary(user, overdueOrders);
  const now = new Date();
  const wasBlocked =
    isActiveManualBlock(user, now) || user.order_block_source === 'overdue_return';

  if (summary.blockSource === 'overdue_return') {
    const blockedAt =
      user.order_block_source === 'overdue_return' && user.order_blocked_at
        ? user.order_blocked_at
        : now;

    await connection.execute(
      `
        UPDATE users
        SET
          order_block_source = 'overdue_return',
          order_block_reason = ?,
          order_blocked_at = ?,
          order_blocked_until = NULL,
          risk_last_reviewed_at = ?
        WHERE id = ?
      `,
      [summary.blockReason, blockedAt, now, userId],
    );

    if (
      !wasBlocked ||
      user.order_block_source !== 'overdue_return' ||
      user.order_block_reason !== summary.blockReason
    ) {
      await insertRiskEvent(connection, {
        userId,
        orderId: overdueOrders[0]?.id || null,
        eventType: 'order_blocked',
        status: 'blocked',
        payload: summary,
      });
    }

    summary.blockedAt = toIso(blockedAt);
    return summary;
  }

  if (summary.blockSource === 'manual') {
    await connection.execute(
      `
        UPDATE users
        SET risk_last_reviewed_at = ?
        WHERE id = ?
      `,
      [now, userId],
    );
    return summary;
  }

  await connection.execute(
    `
      UPDATE users
      SET
        order_block_source = NULL,
        order_block_reason = NULL,
        order_blocked_at = NULL,
        order_blocked_until = NULL,
        risk_last_reviewed_at = ?
      WHERE id = ?
    `,
    [now, userId],
  );

  if (wasBlocked) {
    await insertRiskEvent(connection, {
      userId,
      eventType: 'order_unblocked',
      status: 'clear',
      payload: {
        clearedAt: toIso(now),
        reason: 'Просроченных возвратов больше нет.',
      },
    });
  }

  return summary;
}

async function ensureOrderCreationAllowed(userId, connection) {
  const summary = await syncUserRiskState(userId, connection);
  if (!summary.canCreateOrders) {
    throw httpError(
      409,
      summary.blockReason || 'Оформление новых заказов временно ограничено.',
    );
  }
  return summary;
}

async function listRiskOverview() {
  return withTransaction(async (connection) => {
    const initialUsers = await loadClientUsers(connection);

    for (const user of initialUsers) {
      await syncUserRiskState(user.id, connection);
    }

    const users = await loadClientUsers(connection);
    const overdueRows = await loadAllOverdueReturnOrders(connection);
    const activeRentals = await loadActiveReturnRentals(connection);
    const recentEvents = await loadRecentRiskEvents(connection);

    const overdueByUser = new Map();
    for (const order of overdueRows) {
      const current = overdueByUser.get(order.user_id) || [];
      current.push(order);
      overdueByUser.set(order.user_id, current);
    }

    const serializedUsers = users
      .map((user) =>
        serializeUser(user, buildRiskSummary(user, overdueByUser.get(user.id) || [])),
      )
      .sort((left, right) => {
        if (left.risk.isBlocked !== right.risk.isBlocked) {
          return left.risk.isBlocked ? -1 : 1;
        }
        if (left.risk.overdueActiveOrders !== right.risk.overdueActiveOrders) {
          return right.risk.overdueActiveOrders - left.risk.overdueActiveOrders;
        }
        return left.fullName
          .toLowerCase()
          .localeCompare(right.fullName.toLowerCase(), 'ru');
      });

    return {
      users: serializedUsers,
      activeRentals: activeRentals.map(serializeActiveRental),
      events: recentEvents.map(serializeAdminRiskEvent),
    };
  });
}

async function blockUserOrders(userId, { reason, blockedDays, actor } = {}) {
  const normalizedReason = String(reason || '').trim() || MANUAL_BLOCK_DEFAULT_REASON;
  const normalizedDays = Number(blockedDays || 0);

  return withTransaction(async (connection) => {
    const user = await loadRiskUser(userId, connection);
    if (user.role !== 'client') {
      throw httpError(409, 'Ручная блокировка доступна только для клиентов.');
    }

    const now = new Date();
    const blockedUntil =
      Number.isFinite(normalizedDays) && normalizedDays > 0
        ? new Date(now.getTime() + normalizedDays * 24 * 60 * 60 * 1000)
        : null;

    await connection.execute(
      `
        UPDATE users
        SET
          order_block_source = 'manual',
          order_block_reason = ?,
          order_blocked_at = ?,
          order_blocked_until = ?,
          risk_last_reviewed_at = ?
        WHERE id = ?
      `,
      [normalizedReason, now, blockedUntil, now, userId],
    );

    await insertRiskEvent(connection, {
      userId,
      eventType: 'admin_manual_block',
      status: 'blocked',
      payload: {
        reason: normalizedReason,
        blockedUntil: toIso(blockedUntil),
        actorId: actor?.id || null,
        actorRole: actor?.role || null,
      },
    });

    const summary = await syncUserRiskState(userId, connection);
    const finalUser = await loadRiskUser(userId, connection);
    return serializeUser(finalUser, summary);
  });
}

async function unblockUserOrders(userId, { reason, actor } = {}) {
  const normalizedReason = String(reason || '').trim();

  return withTransaction(async (connection) => {
    const user = await loadRiskUser(userId, connection);
    if (user.role !== 'client') {
      throw httpError(409, 'Ручная разблокировка доступна только для клиентов.');
    }

    const now = new Date();
    await connection.execute(
      `
        UPDATE users
        SET
          order_block_source = NULL,
          order_block_reason = NULL,
          order_blocked_at = NULL,
          order_blocked_until = NULL,
          risk_last_reviewed_at = ?
        WHERE id = ?
      `,
      [now, userId],
    );

    await insertRiskEvent(connection, {
      userId,
      eventType: 'admin_manual_unblock',
      status: 'clear',
      payload: {
        reason: normalizedReason || 'Администратор снял ограничение.',
        actorId: actor?.id || null,
        actorRole: actor?.role || null,
      },
    });

    const summary = await syncUserRiskState(userId, connection);
    const finalUser = await loadRiskUser(userId, connection);
    return serializeUser(finalUser, summary);
  });
}

module.exports = {
  OVERDUE_RETURN_DAYS,
  insertRiskEvent,
  syncUserRiskState,
  ensureOrderCreationAllowed,
  listRiskOverview,
  blockUserOrders,
  unblockUserOrders,
};
