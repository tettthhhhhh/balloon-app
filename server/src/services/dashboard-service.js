const { query } = require('../db/pool');

async function getDashboardStats() {
  const rows = await query(`
    SELECT
      COALESCE(
        SUM(
          CASE
            WHEN status IN ('paid', 'active', 'completed') THEN total_amount
            ELSE 0
          END
        ),
        0
      ) AS totalRevenue,
      SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS waitingOrders,
      SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS activeOrders,
      (
        SELECT COUNT(*)
        FROM orders o
        WHERE o.status = 'active'
          AND o.returned_at IS NULL
          AND o.issued_at IS NOT NULL
          AND o.issued_at < DATE_SUB(CURRENT_TIMESTAMP(3), INTERVAL 3 DAY)
          AND EXISTS (
            SELECT 1
            FROM order_items oi
            WHERE oi.order_id = o.id AND oi.requires_return = 1
          )
      ) AS overdueActiveOrders,
      (
        SELECT COUNT(*)
        FROM (
          SELECT DISTINCT o.user_id AS user_id
          FROM orders o
          WHERE o.status = 'active'
            AND o.returned_at IS NULL
            AND o.issued_at IS NOT NULL
            AND o.issued_at < DATE_SUB(CURRENT_TIMESTAMP(3), INTERVAL 3 DAY)
            AND EXISTS (
              SELECT 1
              FROM order_items oi
              WHERE oi.order_id = o.id AND oi.requires_return = 1
            )
          UNION
          SELECT u.id AS user_id
          FROM users u
          WHERE u.order_block_source = 'manual'
            AND (
              u.order_blocked_until IS NULL OR
              u.order_blocked_until > CURRENT_TIMESTAMP(3)
            )
        ) AS blocked_users
      ) AS blockedUsers,
      (SELECT COUNT(*) FROM products WHERE stock <= 2) AS lowStockProducts
    FROM orders
  `);

  const stats = rows[0] || {};
  return {
    totalRevenue: Number(stats.totalRevenue || 0),
    waitingOrders: Number(stats.waitingOrders || 0),
    activeOrders: Number(stats.activeOrders || 0),
    lowStockProducts: Number(stats.lowStockProducts || 0),
    overdueActiveOrders: Number(stats.overdueActiveOrders || 0),
    blockedUsers: Number(stats.blockedUsers || 0),
  };
}

module.exports = {
  getDashboardStats,
};
